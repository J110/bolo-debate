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

// Expanded fallback topics - diverse and engaging
const fallbackTopics: Record<string, { title: string; sideA: string; sideB: string }[]> = {
  Politics: [
    { title: 'Should voting be made mandatory in India?', sideA: 'Yes, mandatory', sideB: 'No, voluntary' },
    { title: 'Is decentralization the key to better governance?', sideA: 'Support decentralization', sideB: 'Prefer centralization' },
    { title: 'Should there be term limits for elected officials?', sideA: 'Yes, term limits', sideB: 'No term limits' },
    { title: 'Should India have a presidential system?', sideA: 'Yes, presidential', sideB: 'No, parliamentary' },
    { title: 'Is coalition government good for democracy?', sideA: 'Yes, diverse views', sideB: 'No, unstable' },
    { title: 'Should MPs be required to attend Parliament sessions?', sideA: 'Yes, mandatory', sideB: 'No, flexibility needed' },
    { title: 'Should political parties be funded by government?', sideA: 'Yes, transparency', sideB: 'No, private funding' },
    { title: 'Is reservation policy still needed in India?', sideA: 'Yes, still needed', sideB: 'No, merit-based' },
    { title: 'Should minimum education be required for politicians?', sideA: 'Yes, qualification needed', sideB: 'No, democracy for all' },
    { title: 'Should governors have more or less power?', sideA: 'More power', sideB: 'Less power' },
    { title: 'Is one nation one election a good idea?', sideA: 'Yes, efficient', sideB: 'No, federal issues' },
    { title: 'Should MLAs face anti-defection laws?', sideA: 'Yes, strict laws', sideB: 'No, freedom of choice' },
  ],
  Business: [
    { title: 'Should startups prioritize profit or growth?', sideA: 'Profit first', sideB: 'Growth first' },
    { title: 'Is remote work better for productivity?', sideA: 'Remote is better', sideB: 'Office is better' },
    { title: 'Should India focus more on manufacturing or services?', sideA: 'Manufacturing', sideB: 'Services' },
    { title: 'Are family businesses better than corporate?', sideA: 'Family business', sideB: 'Corporate structure' },
    { title: 'Should gig workers get employee benefits?', sideA: 'Yes, benefits needed', sideB: 'No, flexibility trade-off' },
    { title: 'Is entrepreneurship better than a job?', sideA: 'Entrepreneurship', sideB: 'Stable job' },
    { title: 'Should India attract more FDI or support local?', sideA: 'More FDI', sideB: 'Support local' },
    { title: 'Are MBAs overrated in today\'s world?', sideA: 'Yes, overrated', sideB: 'No, still valuable' },
    { title: 'Should companies have 4-day work weeks?', sideA: 'Yes, productivity', sideB: 'No, 5 days needed' },
    { title: 'Is moonlighting ethical for employees?', sideA: 'Yes, fair', sideB: 'No, unethical' },
    { title: 'Should India have more unicorn startups or stable SMEs?', sideA: 'More unicorns', sideB: 'More SMEs' },
    { title: 'Is work from home killing career growth?', sideA: 'Yes, limiting', sideB: 'No, flexible growth' },
  ],
  Sports: [
    { title: 'Should IPL have salary caps?', sideA: 'Yes, for fairness', sideB: 'No, free market' },
    { title: 'Is cricket getting too much attention over other sports?', sideA: 'Yes, too much', sideB: 'No, deserved' },
    { title: 'Should esports be recognized as an official sport?', sideA: 'Yes, recognize', sideB: 'No, not a sport' },
    { title: 'Should Indian athletes get more government support?', sideA: 'Yes, more support', sideB: 'Current is enough' },
    { title: 'Is T20 cricket ruining test cricket?', sideA: 'Yes, hurting tests', sideB: 'No, different formats' },
    { title: 'Should sports betting be legalized in India?', sideA: 'Yes, legalize', sideB: 'No, keep banned' },
    { title: 'Are foreign coaches better for Indian teams?', sideA: 'Yes, foreign', sideB: 'No, Indian coaches' },
    { title: 'Should India host more international sports events?', sideA: 'Yes, more events', sideB: 'No, focus on players' },
    { title: 'Is kabaddi making a real comeback?', sideA: 'Yes, growing', sideB: 'No, still niche' },
    { title: 'Should cricket players play all formats?', sideA: 'Yes, all formats', sideB: 'No, specialize' },
    { title: 'Is Olympic gold more prestigious than World Cup?', sideA: 'Olympic gold', sideB: 'World Cup' },
    { title: 'Should retired players become commentators or coaches?', sideA: 'Commentators', sideB: 'Coaches' },
  ],
  Technology: [
    { title: 'Will AI replace most jobs in the next decade?', sideA: 'Yes, major impact', sideB: 'No, limited impact' },
    { title: 'Should social media be regulated?', sideA: 'Yes, regulate', sideB: 'No, free speech' },
    { title: 'Is privacy more important than convenience?', sideA: 'Privacy first', sideB: 'Convenience first' },
    { title: 'Should children have smartphones before 13?', sideA: 'Yes, early exposure', sideB: 'No, too young' },
    { title: 'Is India ready for 5G revolution?', sideA: 'Yes, ready', sideB: 'No, infrastructure lacking' },
    { title: 'Should coding be mandatory in schools?', sideA: 'Yes, essential skill', sideB: 'No, optional' },
    { title: 'Are electric vehicles the future of India?', sideA: 'Yes, EVs are future', sideB: 'No, hybrid better' },
    { title: 'Should data localization be mandatory?', sideA: 'Yes, security', sideB: 'No, global flow' },
    { title: 'Is UPI better than credit cards?', sideA: 'Yes, UPI better', sideB: 'No, cards better' },
    { title: 'Should India develop its own social media platforms?', sideA: 'Yes, Indian platforms', sideB: 'No, global is fine' },
    { title: 'Is AI-generated content real creativity?', sideA: 'Yes, new creativity', sideB: 'No, not original' },
    { title: 'Should there be digital detox days?', sideA: 'Yes, needed', sideB: 'No, impractical' },
  ],
  Entertainment: [
    { title: 'Are OTT platforms better than traditional cinema?', sideA: 'OTT is better', sideB: 'Cinema is better' },
    { title: 'Should celebrities speak on political issues?', sideA: 'Yes, they should', sideB: 'No, stay neutral' },
    { title: 'Is regional content better than Bollywood now?', sideA: 'Regional is better', sideB: 'Bollywood still rules' },
    { title: 'Are remakes killing original content?', sideA: 'Yes, killing creativity', sideB: 'No, good adaptations' },
    { title: 'Should movie tickets be price capped?', sideA: 'Yes, affordable', sideB: 'No, market decides' },
    { title: 'Is stand-up comedy the new entertainment king?', sideA: 'Yes, comedy rising', sideB: 'No, still niche' },
    { title: 'Should award shows be taken seriously?', sideA: 'Yes, recognition', sideB: 'No, just PR' },
    { title: 'Are influencers replacing traditional celebrities?', sideA: 'Yes, new era', sideB: 'No, celebs still rule' },
    { title: 'Is binge-watching harmful?', sideA: 'Yes, unhealthy', sideB: 'No, personal choice' },
    { title: 'Should there be more content regulation?', sideA: 'Yes, regulate', sideB: 'No, creative freedom' },
    { title: 'Are short videos killing attention spans?', sideA: 'Yes, harmful', sideB: 'No, just evolution' },
    { title: 'Is music industry better with streaming?', sideA: 'Yes, more access', sideB: 'No, artists suffer' },
  ],
  default: [
    { title: 'Is work-life balance achievable in today\'s world?', sideA: 'Yes, achievable', sideB: 'No, unrealistic' },
    { title: 'Should education be completely free?', sideA: 'Yes, free for all', sideB: 'No, some cost needed' },
    { title: 'Is urban life better than rural life?', sideA: 'Urban is better', sideB: 'Rural is better' },
    { title: 'Should plastic be completely banned?', sideA: 'Yes, ban it', sideB: 'No, regulate instead' },
    { title: 'Is joint family system still relevant?', sideA: 'Yes, valuable', sideB: 'No, outdated' },
    { title: 'Should India have uniform civil code?', sideA: 'Yes, uniform', sideB: 'No, diversity' },
    { title: 'Is online education as effective as classroom?', sideA: 'Yes, equally good', sideB: 'No, classroom better' },
    { title: 'Should tipping culture be adopted in India?', sideA: 'Yes, adopt it', sideB: 'No, fair wages instead' },
    { title: 'Is arranged marriage still a good system?', sideA: 'Yes, works well', sideB: 'No, outdated' },
    { title: 'Should public transport be free?', sideA: 'Yes, free for all', sideB: 'No, subsidies enough' },
    { title: 'Is vegetarianism better for health?', sideA: 'Yes, healthier', sideB: 'No, balance needed' },
    { title: 'Should there be a retirement age limit?', sideA: 'Yes, make room', sideB: 'No, experience matters' },
  ],
};

// Region-specific topic variations for local flavor
const regionTopicPrefixes: Record<string, string[]> = {
  'Mumbai': ['In Mumbai,', 'For Mumbaikars,', 'In Maharashtra,'],
  'Delhi NCR': ['In Delhi,', 'For Delhi-NCR,', 'In the capital,'],
  'Bangalore': ['In Bangalore,', 'For Bengaluru,', 'In Karnataka,'],
  'Chennai': ['In Chennai,', 'For Tamil Nadu,', 'In South India,'],
  'Hyderabad': ['In Hyderabad,', 'For Telangana,', 'In the Deccan,'],
  'Kolkata': ['In Kolkata,', 'For West Bengal,', 'In East India,'],
  'National': ['For India,', 'Across India,', 'For all Indians,'],
};

// Track recently used topics to avoid duplicates
const recentlyUsedTopics = new Set<string>();
const MAX_RECENT_TOPICS = 50;

function addToRecentTopics(title: string) {
  recentlyUsedTopics.add(title);
  if (recentlyUsedTopics.size > MAX_RECENT_TOPICS) {
    const first = recentlyUsedTopics.values().next().value as string | undefined;
    if (first) {
      recentlyUsedTopics.delete(first);
    }
  }
}

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

  // Not enough cached topics - use fallback with duplicate prevention
  // First, get currently active room titles to avoid duplicates
  const activeRooms = await prisma.room.findMany({
    where: {
      status: { in: ['LIVE', 'SCHEDULED'] },
      isAiHosted: true,
    },
    select: { title: true },
  });
  const activeTopicTitles = new Set(activeRooms.map(r => r.title));

  const categoryTopics = fallbackTopics[category.name] || fallbackTopics.default;
  // Also include default topics for variety
  const allTopics = [...categoryTopics, ...fallbackTopics.default];
  
  // Filter out recently used and currently active topics
  const availableTopics = allTopics.filter(t => 
    !recentlyUsedTopics.has(t.title) && !activeTopicTitles.has(t.title)
  );
  
  // If all topics are used, just shuffle all topics (reset cycle)
  const topicsToUse = availableTopics.length >= count ? availableTopics : allTopics;
  const shuffled = topicsToUse.sort(() => Math.random() - 0.5);
  
  console.log(`⚠️ No cached topics for ${category.name} in ${region.name}, using fallback (${availableTopics.length} unique available)`);
  
  const selectedTopics = shuffled.slice(0, count);
  // Track the selected topics
  selectedTopics.forEach(t => addToRecentTopics(t.title));
  
  return selectedTopics.map(topic => ({
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
  
  // Region-specific context for local relevance
  const regionExamples: Record<string, string> = {
    'Mumbai': 'local train issues, Marathi manoos, housing costs, BMC policies, film industry',
    'Delhi NCR': 'pollution, metro expansion, water crisis, political dynamics, NCR development',
    'Bangalore': 'traffic congestion, IT industry, Kannada language, startup culture, lake restoration',
    'Chennai': 'Tamil culture, IT corridor, metro water, language politics, film industry',
    'Hyderabad': 'IT growth, old city vs new city, Telugu pride, pharma industry, infrastructure',
    'Kolkata': 'heritage preservation, political scene, cultural events, metro expansion, employment',
  };
  
  const localContext = regionExamples[region.name] || 'local governance, infrastructure, culture';
  
  const regionContext = isNational 
    ? 'Generate pan-India topics relevant to all Indians - national policies, economy, education, healthcare.'
    : `Generate topics specific to ${region.name}, ${region.state}. Consider: ${localContext}. Make topics feel LOCAL and relevant to residents.`;
  
  const prompt = `Generate ${count} UNIQUE and DIVERSE debate topics for an audio discussion platform in India.

${regionContext}
Category: ${category.name}

CRITICAL REQUIREMENTS:
1. Topics must be in ENGLISH only
2. Topics must be CURRENT and TIMELY - reference recent events, trends, or ongoing issues
3. Topics must be UNIQUE - do NOT use generic topics like "work-life balance" or "AI replacing jobs"
4. Topics must be DEBATABLE with clear opposing viewpoints
5. Topics should be ENGAGING and provocative (but respectful)
6. ${isNational ? 'Focus on national-level issues that affect all Indians' : 'Focus on LOCAL issues specific to ' + region.name + ' - avoid generic topics'}

For each topic, provide:
- title: A compelling, specific question in English (max 100 chars) - make it feel fresh and relevant
- description: Brief context about why this topic matters NOW (max 200 chars)
- sideALabel: Clear position label (e.g., "Support", "Yes", "In Favor") (max 30 chars)
- sideBLabel: Clear opposing position (e.g., "Oppose", "No", "Against") (max 30 chars)

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
    ? 'Pan-India topics relevant to all Indians - national policies, economy, education.'
    : `Topics specific to ${region.name}, ${region.state}. Focus on LOCAL issues that matter to residents.`;
  
  const prompt = `Generate ${count} UNIQUE debate topics for an Indian audio discussion platform.

${regionContext}
Category: ${category.name}

Requirements:
1. Topics MUST be in ENGLISH only
2. Topics must be CURRENT and specific - avoid generic topics
3. Topics must be DEBATABLE with clear opposing viewpoints
4. ${isNational ? 'Focus on national-level Indian issues' : 'Focus on LOCAL ' + region.name + ' issues'}

For each topic provide JSON with:
- title: Specific question in English (max 100 chars)
- description: Why this matters now (max 200 chars)
- sideALabel: Position label (max 30 chars)
- sideBLabel: Opposing position (max 30 chars)

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
