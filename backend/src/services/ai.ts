import OpenAI from 'openai';
import { config } from '../config/index.js';
import { prisma } from '../config/database.js';

// Check available AI providers (priority: Groq > Ollama > OpenAI > Fallback)
const hasGroq = config.groq.apiKey && config.groq.apiKey.length > 10;
const hasOpenAI = config.openai.apiKey && 
  config.openai.apiKey.length > 10 && 
  config.openai.apiKey.startsWith('sk-');
const hasOllama = config.ollama.url && config.ollama.url.length > 0;

// Groq client (uses OpenAI-compatible API)
const groq = hasGroq ? new OpenAI({
  apiKey: config.groq.apiKey,
  baseURL: 'https://api.groq.com/openai/v1',
}) : null;

// OpenAI client (fallback if Groq not available)
const openai = hasOpenAI ? new OpenAI({
  apiKey: config.openai.apiKey,
}) : null;

// Track last batch generation time to avoid over-calling
let lastBatchGenerationTime = 0;
const BATCH_GENERATION_INTERVAL = 60 * 60 * 1000; // 1 hour minimum between batch generations
const MIN_TOPICS_PER_CATEGORY = 5; // Minimum cached topics before regenerating

// Log available providers
if (hasGroq) {
  console.log('✅ Groq API configured (FREE) - primary AI provider');
} 
if (hasOllama) {
  console.log('✅ Ollama configured at', config.ollama.url, '- self-hosted fallback');
}
if (hasOpenAI) {
  console.log('✅ OpenAI API configured - backup provider');
}
if (!hasGroq && !hasOpenAI && !hasOllama) {
  console.log('⚠️ No AI provider configured - using fallback topics');
}

// Topics should be relevant to the region but text always in English
// Room language will be randomly Hindi or English (handled in room service)

interface GeneratedTopic {
  title: string;
  description: string;
  sideALabel: string;
  sideBLabel: string;
  categoryId: string;
  regionId: string;
}

interface DebateSuggestion {
  forSideA: string[];
  forSideB: string[];
  neutral: string[];
}

// Fallback topics for when OpenAI is not available
const fallbackTopics: Record<string, { title: string; sideA: string; sideB: string }[]> = {
  Politics: [
    { title: 'Should voting be made mandatory in India?', sideA: 'Yes, mandatory', sideB: 'No, voluntary' },
    { title: 'Is decentralization the key to better governance?', sideA: 'Support decentralization', sideB: 'Prefer centralization' },
    { title: 'Should there be term limits for elected officials?', sideA: 'Yes, term limits', sideB: 'No term limits' },
  ],
  Business: [
    { title: 'Should startups prioritize profit or growth?', sideA: 'Profit first', sideB: 'Growth first' },
    { title: 'Is remote work better for productivity?', sideA: 'Remote is better', sideB: 'Office is better' },
    { title: 'Should India focus more on manufacturing or services?', sideA: 'Manufacturing', sideB: 'Services' },
  ],
  Sports: [
    { title: 'Should IPL have salary caps?', sideA: 'Yes, for fairness', sideB: 'No, free market' },
    { title: 'Is cricket getting too much attention over other sports?', sideA: 'Yes, too much', sideB: 'No, deserved' },
    { title: 'Should esports be recognized as an official sport?', sideA: 'Yes, recognize', sideB: 'No, not a sport' },
  ],
  Technology: [
    { title: 'Will AI replace most jobs in the next decade?', sideA: 'Yes, major impact', sideB: 'No, limited impact' },
    { title: 'Should social media be regulated?', sideA: 'Yes, regulate', sideB: 'No, free speech' },
    { title: 'Is privacy more important than convenience?', sideA: 'Privacy first', sideB: 'Convenience first' },
  ],
  Entertainment: [
    { title: 'Are OTT platforms better than traditional cinema?', sideA: 'OTT is better', sideB: 'Cinema is better' },
    { title: 'Should celebrities speak on political issues?', sideA: 'Yes, they should', sideB: 'No, stay neutral' },
    { title: 'Is regional content better than Bollywood now?', sideA: 'Regional is better', sideB: 'Bollywood still rules' },
  ],
  default: [
    { title: 'Is work-life balance achievable in today\'s world?', sideA: 'Yes, achievable', sideB: 'No, unrealistic' },
    { title: 'Should education be completely free?', sideA: 'Yes, free for all', sideB: 'No, some cost needed' },
    { title: 'Is urban life better than rural life?', sideA: 'Urban is better', sideB: 'Rural is better' },
  ],
};

// Get a topic from cache first, only generate if needed
export async function generateDebateTopics(
  regionId: string,
  categoryId: string,
  count: number = 1
): Promise<GeneratedTopic[]> {
  const [region, category] = await Promise.all([
    prisma.region.findUnique({ where: { id: regionId } }),
    prisma.category.findUnique({ where: { id: categoryId } }),
  ]);

  if (!region || !category) {
    throw new Error('Invalid region or category');
  }

  // First, try to get from topic queue cache
  const cachedTopics = await prisma.topicQueue.findMany({
    where: {
      regionId,
      categoryId,
      isUsed: false,
    },
    take: count,
    orderBy: { createdAt: 'asc' },
  });

  if (cachedTopics.length >= count) {
    // Mark topics as used
    await prisma.topicQueue.updateMany({
      where: { id: { in: cachedTopics.map(t => t.id) } },
      data: { isUsed: true, usedAt: new Date() },
    });

    console.log(`📦 Using ${cachedTopics.length} cached topics for ${category.name}`);
    
    return cachedTopics.map(topic => ({
      title: topic.title,
      description: topic.description || '',
      sideALabel: topic.sideALabel,
      sideBLabel: topic.sideBLabel,
      categoryId,
      regionId,
    }));
  }

  // Not enough cached topics - use fallback (don't call OpenAI on each request)
  const categoryTopics = fallbackTopics[category.name] || fallbackTopics.default;
  const shuffled = categoryTopics.sort(() => Math.random() - 0.5);
  
  console.log(`⚠️ No cached topics for ${category.name}, using fallback`);
  
  return shuffled.slice(0, count).map(topic => ({
    title: topic.title,
    description: `A debate topic for ${region.name} community`,
    sideALabel: topic.sideA,
    sideBLabel: topic.sideB,
    categoryId,
    regionId,
  }));
}

// Batch generate topics - call this once per hour via scheduler
export async function batchGenerateTopics(topicsPerCategory: number = 10): Promise<number> {
  // Check if enough time has passed since last generation
  const now = Date.now();
  if (now - lastBatchGenerationTime < BATCH_GENERATION_INTERVAL) {
    const minsRemaining = Math.ceil((BATCH_GENERATION_INTERVAL - (now - lastBatchGenerationTime)) / 60000);
    console.log(`⏳ Batch generation skipped - ${minsRemaining} minutes until next batch`);
    return 0;
  }

  // Check if any AI provider is available
  if (!hasGroq && !hasOpenAI && !hasOllama) {
    console.log('⚠️ No AI provider configured - cannot batch generate topics');
    return 0;
  }

  const regions = await prisma.region.findMany({ take: 3 }); // Limit to 3 regions
  const categories = await prisma.category.findMany();
  
  let totalGenerated = 0;

  for (const region of regions) {
    for (const category of categories) {
      // Check how many unused topics we have
      const unusedCount = await prisma.topicQueue.count({
        where: { regionId: region.id, categoryId: category.id, isUsed: false },
      });

      if (unusedCount >= MIN_TOPICS_PER_CATEGORY) {
        continue; // Enough cached topics
      }

      const toGenerate = Math.min(topicsPerCategory, MIN_TOPICS_PER_CATEGORY * 2 - unusedCount);
      
      try {
        const topics = await generateTopicsWithAI(region, category, toGenerate);
        
        // Save to queue
        for (const topic of topics) {
          await prisma.topicQueue.create({
            data: {
              regionId: region.id,
              categoryId: category.id,
              title: topic.title,
              description: topic.description,
              sideALabel: topic.sideALabel,
              sideBLabel: topic.sideBLabel,
            },
          });
        }
        
        totalGenerated += topics.length;
        console.log(`✅ Generated ${topics.length} topics for ${category.name} in ${region.name}`);
        
        // Small delay to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 300));
      } catch (error) {
        console.error(`Error generating topics for ${category.name}:`, error);
      }
    }
  }

  lastBatchGenerationTime = now;
  console.log(`📊 Batch generation complete: ${totalGenerated} topics created`);
  return totalGenerated;
}

// Groq model configuration
// Using llama-3.1-8b-instant (replacement for deprecated llama3-8b-8192)
// Good rate limits and multilingual support
const GROQ_MODEL = 'llama-3.1-8b-instant';

// Generate topics using available AI provider (Groq > Ollama > OpenAI)
async function generateTopicsWithAI(
  region: { name: string; state: string },
  category: { name: string },
  count: number
): Promise<{ title: string; description: string; sideALabel: string; sideBLabel: string }[]> {
  
  // Try Groq first (free and fast)
  if (hasGroq && groq) {
    try {
      return await callLLM(groq, GROQ_MODEL, region, category, count);
    } catch (error) {
      console.log('Groq failed, trying fallback:', error);
    }
  }
  
  // Try Ollama (self-hosted)
  if (hasOllama) {
    try {
      return await callOllama(region, category, count);
    } catch (error) {
      console.log('Ollama failed, trying fallback:', error);
    }
  }
  
  // Try OpenAI as last resort
  if (hasOpenAI && openai) {
    try {
      return await callLLM(openai, 'gpt-4-turbo-preview', region, category, count);
    } catch (error) {
      console.log('OpenAI failed:', error);
    }
  }
  
  return [];
}

// Call OpenAI-compatible API (works for Groq and OpenAI)
async function callLLM(
  client: OpenAI,
  model: string,
  region: { name: string; state: string },
  category: { name: string },
  count: number
): Promise<{ title: string; description: string; sideALabel: string; sideBLabel: string }[]> {
  // For National region, generate pan-India topics
  const isNational = region.name === 'National';
  const regionContext = isNational 
    ? 'This is for pan-India discussions, covering topics relevant to all of India.'
    : `Region: ${region.name}, ${region.state}. Topics should be relevant to local issues and culture.`;
  
  const prompt = `Generate ${count} engaging debate topics for an audio discussion platform in India.

${regionContext}
Category: ${category.name}

Requirements:
1. Topics should be in ENGLISH only
2. Topics should be relevant to ${isNational ? 'national issues affecting all Indians' : 'the local region and current affairs'}
3. Topics should be debatable with clear opposing viewpoints
4. Topics should be respectful and not promote hate or discrimination
5. Topics should be engaging and encourage healthy discussion

For each topic, provide:
- title: A compelling question or statement in English (max 100 chars)
- description: Brief context about the topic (max 200 chars)
- sideALabel: Label for one side (e.g., "Support", "In Favor", "Yes") (max 30 chars)
- sideBLabel: Label for opposing side (e.g., "Oppose", "Against", "No") (max 30 chars)

Respond in JSON format: { "topics": [...] }`;

  const response = await client.chat.completions.create({
    model,
    messages: [
      {
        role: 'system',
        content: 'You are a helpful assistant that generates engaging debate topics for an Indian audio discussion platform. Always respond with valid JSON. Generate topics in English only.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ],
    response_format: { type: 'json_object' },
    temperature: 0.8,
    max_tokens: 2000,
  });

  const content = response.choices[0]?.message?.content;
  if (!content) {
    throw new Error('No response from LLM');
  }

  const parsed = JSON.parse(content);
  const topics = parsed.topics || parsed;

  return (Array.isArray(topics) ? topics : [topics]).map((topic: any) => ({
    title: topic.title || 'Untitled Topic',
    description: topic.description || '',
    sideALabel: topic.sideALabel || 'In Favor',
    sideBLabel: topic.sideBLabel || 'Against',
  }));
}

// Call self-hosted Ollama for topic generation
async function callOllama(
  region: { name: string; state: string },
  category: { name: string },
  count: number
): Promise<{ title: string; description: string; sideALabel: string; sideBLabel: string }[]> {
  // Use a good general model
  const model = 'llama3.1:8b';
  
  // For National region, generate pan-India topics
  const isNational = region.name === 'National';
  const regionContext = isNational 
    ? 'Pan-India discussions covering topics relevant to all of India.'
    : `Region: ${region.name}, ${region.state}. Topics should be relevant to local issues.`;
  
  const prompt = `Generate ${count} engaging debate topics for an audio discussion platform in India.

${regionContext}
Category: ${category.name}

Requirements:
1. Topics must be in ENGLISH only
2. Topics should be relevant to ${isNational ? 'national issues' : 'the local region'}
3. Topics should be debatable with clear opposing viewpoints
4. Topics should be respectful

For each topic, provide:
- title: A compelling question in English (max 100 chars)
- description: Brief context (max 200 chars)
- sideALabel: Label for one side (max 30 chars)
- sideBLabel: Label for opposing side (max 30 chars)

Respond ONLY with valid JSON: { "topics": [...] }`;

  const response = await fetch(`${config.ollama.url}/api/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model,
      prompt: `You are an assistant that generates debate topics in English. Generate debate topics in JSON format.\n\n${prompt}`,
      stream: false,
      format: 'json',
    }),
  });

  if (!response.ok) {
    throw new Error(`Ollama error: ${response.status}`);
  }

  const data = await response.json() as { response: string };
  const parsed = JSON.parse(data.response);
  const topics = parsed.topics || parsed;

  return (Array.isArray(topics) ? topics : [topics]).map((topic: any) => ({
    title: topic.title || 'Untitled Topic',
    description: topic.description || '',
    sideALabel: topic.sideALabel || 'In Favor',
    sideBLabel: topic.sideBLabel || 'Against',
  }));
}

export async function generateDebateSuggestions(
  topic: string,
  sideALabel: string,
  sideBLabel: string,
  context?: string
): Promise<DebateSuggestion> {
  const fallback = {
    forSideA: ['Consider the benefits and positive outcomes', 'Think about real-world examples', 'Address common concerns'],
    forSideB: ['Consider potential drawbacks', 'Think about alternative approaches', 'Address counterarguments'],
    neutral: ['Look at both perspectives objectively', 'Consider the middle ground', 'Focus on facts and evidence'],
  };

  // Return fallback if no AI provider available
  if (!hasGroq && !hasOpenAI && !hasOllama) {
    return fallback;
  }

  const prompt = `You are helping participants in an audio debate about:
Topic: "${topic}"
Side A (${sideALabel}) vs Side B (${sideBLabel})
${context ? `Recent discussion context: ${context}` : ''}

Generate helpful talking points for both sides and neutral perspectives.
For each side, provide 3 concise bullet points (max 100 chars each) that participants could use.

Respond in JSON format:
{
  "forSideA": ["point1", "point2", "point3"],
  "forSideB": ["point1", "point2", "point3"],
  "neutral": ["point1", "point2", "point3"]
}`;

  const messages = [
    {
      role: 'system' as const,
      content: 'You are a helpful debate moderator assistant. Generate balanced, respectful talking points. Always respond with valid JSON.',
    },
    {
      role: 'user' as const,
      content: prompt,
    },
  ];

  try {
    // Try Groq first (free)
    if (hasGroq && groq) {
      const response = await groq.chat.completions.create({
        model: GROQ_MODEL,
        messages,
        response_format: { type: 'json_object' },
        temperature: 0.7,
        max_tokens: 800,
      });
      const content = response.choices[0]?.message?.content;
      if (content) return JSON.parse(content);
    }

    // Try OpenAI as fallback
    if (hasOpenAI && openai) {
      const response = await openai.chat.completions.create({
        model: 'gpt-4-turbo-preview',
        messages,
        response_format: { type: 'json_object' },
        temperature: 0.7,
        max_tokens: 800,
      });
      const content = response.choices[0]?.message?.content;
      if (content) return JSON.parse(content);
    }

    return fallback;
  } catch (error) {
    console.error('Error generating debate suggestions:', error);
    return fallback;
  }
}

export async function generateSubtopics(
  mainTopic: string,
  count: number = 5
): Promise<string[]> {
  const fallback = [
    'What are the immediate impacts?',
    'How does this affect different groups?',
    'What are the long-term consequences?',
    'Are there alternative solutions?',
    'What lessons can we learn from similar situations?',
  ];

  // Return fallback if no AI provider
  if (!hasGroq && !hasOpenAI && !hasOllama) {
    return fallback;
  }

  const prompt = `For the debate topic: "${mainTopic}"

Generate ${count} related subtopics that a host could introduce to keep the discussion engaging and explore different angles.

Each subtopic should be a concise question or statement (max 80 chars).

Respond in JSON format: { "subtopics": ["subtopic1", "subtopic2", ...] }`;

  const messages = [
    {
      role: 'system' as const,
      content: 'You are a helpful debate moderator assistant. Generate engaging subtopics. Always respond with valid JSON.',
    },
    {
      role: 'user' as const,
      content: prompt,
    },
  ];

  try {
    // Try Groq first (free)
    if (hasGroq && groq) {
      const response = await groq.chat.completions.create({
        model: GROQ_MODEL,
        messages,
        response_format: { type: 'json_object' },
        temperature: 0.8,
        max_tokens: 500,
      });
      const content = response.choices[0]?.message?.content;
      if (content) {
        const parsed = JSON.parse(content);
        return parsed.subtopics || fallback;
      }
    }

    // Try OpenAI as fallback
    if (hasOpenAI && openai) {
      const response = await openai.chat.completions.create({
        model: 'gpt-4-turbo-preview',
        messages,
        response_format: { type: 'json_object' },
        temperature: 0.8,
        max_tokens: 500,
      });
      const content = response.choices[0]?.message?.content;
      if (content) {
        const parsed = JSON.parse(content);
        return parsed.subtopics || fallback;
      }
    }

    return fallback;
  } catch (error) {
    console.error('Error generating subtopics:', error);
    return fallback;
  }
}

export async function generateHostingTips(): Promise<string[]> {
  return [
    'Welcome new participants and briefly explain the topic',
    'Ensure both sides get equal time to speak',
    'Gently steer the conversation back if it goes off-topic',
    'Acknowledge good points from both sides',
    'Summarize key arguments periodically',
    'Keep the energy up by asking follow-up questions',
    'Remind participants to be respectful',
    'Give a 5-minute warning before the room ends',
    'Thank everyone for participating at the end',
  ];
}

// Pre-defined bot messages for when OpenAI is not available
const botMessages = [
  "Great points from both sides! What real-world examples can support your arguments?",
  "Consider how this topic affects different age groups or demographics.",
  "Let's hear from someone who hasn't spoken yet!",
  "What's a common misconception about this topic?",
  "How might this issue look different 10 years from now?",
  "Can anyone share a personal experience related to this?",
  "What compromises could both sides agree on?",
  "Let's focus on the facts - what data supports each position?",
];

export async function generateBotMessage(
  roomId: string,
  topic: string,
  sideALabel: string,
  sideBLabel: string
): Promise<string | null> {
  // Return random fallback message if no OpenAI
  if (!openai) {
    return botMessages[Math.floor(Math.random() * botMessages.length)];
  }

  // Get recent messages for context
  const recentMessages = await prisma.message.findMany({
    where: { roomId, isBot: false },
    orderBy: { createdAt: 'desc' },
    take: 10,
    select: { content: true },
  });

  if (recentMessages.length < 5) {
    // Not enough discussion yet
    return null;
  }

  const context = recentMessages.map(m => m.content).reverse().join('\n');

  const prompt = `You are a helpful bot in a debate room.
Topic: "${topic}"
Sides: ${sideALabel} vs ${sideBLabel}

Recent discussion:
${context}

Generate ONE short, helpful suggestion (max 150 chars) to:
- Introduce a new angle to consider
- Encourage quieter participants
- Summarize a key point made
- Suggest a thought-provoking question

Keep it brief and constructive. Just output the suggestion, no prefix.`;

  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        {
          role: 'system',
          content: 'You are a helpful, brief debate assistant bot. Keep responses under 150 characters.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: 0.7,
      max_tokens: 100,
    });

    return response.choices[0]?.message?.content?.trim() || null;
  } catch (error) {
    console.error('Error generating bot message:', error);
    return null;
  }
}
