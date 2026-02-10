import Parser from 'rss-parser';
import { prisma } from '../config/database.js';
import { TopicType } from '@prisma/client';
import { canUseTopic } from './duplicate-checker.js';

const parser = new Parser({
  timeout: 10000,
  headers: {
    'User-Agent': 'Mozilla/5.0 (compatible; BoloDebate/1.0)',
    'Accept': 'application/rss+xml, application/xml, text/xml'
  }
});

// International RSS feeds interesting to Indian audience
const INTERNATIONAL_FEEDS = [
  // BBC World
  { url: 'https://feeds.bbci.co.uk/news/world/rss.xml', source: 'BBC World', category: 'Politics' },
  { url: 'https://feeds.bbci.co.uk/news/technology/rss.xml', source: 'BBC Tech', category: 'Technology' },
  { url: 'https://feeds.bbci.co.uk/news/business/rss.xml', source: 'BBC Business', category: 'Business' },
  { url: 'https://feeds.bbci.co.uk/sport/rss.xml', source: 'BBC Sport', category: 'Sports' },
  
  // Reuters
  { url: 'https://www.reutersagency.com/feed/?best-topics=tech&post_type=best', source: 'Reuters Tech', category: 'Technology' },
  { url: 'https://www.reutersagency.com/feed/?best-topics=business-finance&post_type=best', source: 'Reuters Business', category: 'Business' },
  
  // ESPN (Sports)
  { url: 'https://www.espn.com/espn/rss/news', source: 'ESPN', category: 'Sports' },
  
  // TechCrunch
  { url: 'https://techcrunch.com/feed/', source: 'TechCrunch', category: 'Technology' },
  
  // The Verge
  { url: 'https://www.theverge.com/rss/index.xml', source: 'The Verge', category: 'Technology' },
];

// Keywords that indicate topics interesting to Indian audience
const INDIA_INTEREST_KEYWORDS = [
  // Cricket and sports
  'cricket', 'icc', 'world cup', 'olympics', 'asian games', 'commonwealth',
  'badminton', 'tennis', 'formula 1', 'f1', 'football', 'fifa',
  
  // Tech companies with Indian presence
  'google', 'microsoft', 'amazon', 'apple', 'meta', 'facebook', 'twitter', 'x',
  'openai', 'chatgpt', 'ai', 'artificial intelligence', 'tesla', 'elon musk',
  'tiktok', 'instagram', 'whatsapp', 'youtube', 'netflix', 'spotify',
  
  // Global economy
  'economy', 'inflation', 'recession', 'stock market', 'oil prices', 'gold',
  'cryptocurrency', 'bitcoin', 'trade', 'tariff', 'sanctions',
  
  // Geopolitics relevant to India
  'china', 'pakistan', 'usa', 'russia', 'ukraine', 'israel', 'middle east',
  'climate change', 'global warming', 'cop', 'un', 'g20', 'brics',
  
  // Entertainment
  'hollywood', 'oscars', 'grammy', 'emmy', 'marvel', 'dc', 'disney',
  'streaming', 'box office',
  
  // Science and Space
  'nasa', 'space', 'isro', 'moon', 'mars', 'satellite', 'rocket',
  
  // Health
  'who', 'pandemic', 'vaccine', 'health', 'disease',
];

// Category ID cache
let categoryIdMap: Map<string, string> | null = null;

async function getCategoryIdMap(): Promise<Map<string, string>> {
  if (categoryIdMap) return categoryIdMap;
  
  const categories = await prisma.category.findMany({
    select: { id: true, name: true }
  });
  
  categoryIdMap = new Map(categories.map(c => [c.name, c.id]));
  return categoryIdMap;
}

/**
 * Checks if a headline is interesting to Indian audience
 */
function isInterestingToIndianAudience(headline: string): boolean {
  const lowerHeadline = headline.toLowerCase();
  return INDIA_INTEREST_KEYWORDS.some(keyword => lowerHeadline.includes(keyword));
}

/**
 * Classifies an international headline into a category
 */
function classifyCategory(headline: string, defaultCategory: string): string {
  const lower = headline.toLowerCase();
  
  // Sports keywords
  if (/cricket|football|tennis|olympics|championship|world cup|match|player|team|score|win|lose|tournament/i.test(lower)) {
    return 'Sports';
  }
  
  // Technology keywords
  if (/tech|ai|artificial intelligence|software|app|smartphone|computer|internet|cyber|robot|startup|innovation/i.test(lower)) {
    return 'Technology';
  }
  
  // Business keywords
  if (/economy|stock|market|company|business|trade|investment|bank|financial|profit|revenue|merger|acquisition/i.test(lower)) {
    return 'Business';
  }
  
  // Entertainment keywords
  if (/movie|film|actor|actress|music|song|album|concert|celebrity|award|oscar|grammy|netflix|disney/i.test(lower)) {
    return 'Entertainment';
  }
  
  // Politics keywords
  if (/government|president|minister|election|vote|parliament|congress|policy|law|sanction|treaty|summit/i.test(lower)) {
    return 'Politics';
  }
  
  return defaultCategory;
}

/**
 * Fetches international news from RSS feeds
 */
export async function fetchInternationalNews(): Promise<{
  headline: string;
  summary: string;
  sourceUrl: string;
  sourceName: string;
  category: string;
  publishedAt: Date;
}[]> {
  const allItems: {
    headline: string;
    summary: string;
    sourceUrl: string;
    sourceName: string;
    category: string;
    publishedAt: Date;
  }[] = [];
  
  console.log('🌍 Fetching international news...');
  
  for (const feed of INTERNATIONAL_FEEDS) {
    try {
      const result = await parser.parseURL(feed.url);
      
      for (const item of result.items.slice(0, 10)) { // Top 10 from each feed
        if (!item.title) continue;
        
        // Check if interesting to Indian audience
        if (!isInterestingToIndianAudience(item.title)) continue;
        
        const category = classifyCategory(item.title, feed.category);
        
        allItems.push({
          headline: item.title,
          summary: item.contentSnippet || item.content || '',
          sourceUrl: item.link || '',
          sourceName: feed.source,
          category,
          publishedAt: item.pubDate ? new Date(item.pubDate) : new Date()
        });
      }
      
      console.log(`  ✓ ${feed.source}: ${result.items.length} items`);
    } catch (error) {
      console.error(`  ✗ ${feed.source}: Failed to fetch`, error);
    }
  }
  
  console.log(`🌍 Found ${allItems.length} international items relevant to Indian audience`);
  return allItems;
}

/**
 * Stores international news items as TrendingItems
 */
export async function storeInternationalTrending(): Promise<number> {
  const items = await fetchInternationalNews();
  const categoryMap = await getCategoryIdMap();
  let storedCount = 0;
  
  for (const item of items) {
    const categoryId = categoryMap.get(item.category);
    if (!categoryId) continue;
    
    // Check for duplicates by headline
    const existing = await prisma.trendingItem.findFirst({
      where: {
        headline: item.headline
      }
    });
    
    if (existing) continue;
    
    // Set expiry to 48 hours for international news
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 48);
    
    try {
      await prisma.trendingItem.create({
        data: {
          headline: item.headline,
          summary: item.summary.substring(0, 500),
          sourceUrl: item.sourceUrl,
          sourceName: `[INTL] ${item.sourceName}`,
          categoryId,
          publishedAt: item.publishedAt,
          trendingScore: 1.2, // Slightly higher score for international
          expiresAt
        }
      });
      storedCount++;
    } catch (error) {
      // Ignore duplicate errors
    }
  }
  
  console.log(`🌍 Stored ${storedCount} new international trending items`);
  return storedCount;
}

/**
 * Converts international trending items to debate topics using AI
 */
export async function convertInternationalToTopics(limit: number = 10): Promise<number> {
  // Import AI service dynamically
  const { convertTrendingToTopic } = await import('./ai.js');
  const categoryMap = await getCategoryIdMap();
  
  // Get unprocessed international trending items
  const items = await prisma.trendingItem.findMany({
    where: {
      isProcessed: false,
      sourceName: { startsWith: '[INTL]' },
      expiresAt: { gt: new Date() }
    },
    orderBy: { trendingScore: 'desc' },
    take: limit
  });
  
  if (items.length === 0) {
    console.log('🌍 No international items to convert');
    return 0;
  }
  
  console.log(`🌍 Converting ${items.length} international items to topics...`);
  let convertedCount = 0;
  
  for (const item of items) {
    try {
      // Convert using AI
      const topic = await convertTrendingToTopic(item.headline, item.summary || '');
      
      if (!topic) {
        await prisma.trendingItem.update({
          where: { id: item.id },
          data: { isProcessed: true }
        });
        continue;
      }
      
      // Check for duplicates
      const { canUse } = await canUseTopic(topic.title);
      if (!canUse) {
        await prisma.trendingItem.update({
          where: { id: item.id },
          data: { isProcessed: true }
        });
        continue;
      }
      
      // Determine language (50% Hindi, 50% English)
      const language = Math.random() > 0.5 ? 'Hindi' : 'English';
      
      // Set expiry to 24 hours
      const expiresAt = new Date();
      expiresAt.setHours(expiresAt.getHours() + 24);
      
      // Create topic in queue
      await prisma.topicQueue.create({
        data: {
          categoryId: item.categoryId!,
          title: topic.title,
          description: topic.description,
          sideALabel: topic.sideA,
          sideBLabel: topic.sideB,
          topicType: 'INTERNATIONAL',
          language,
          regionTags: ['International', 'National'], // Available everywhere
          sourceHeadline: item.headline,
          sourceUrl: item.sourceUrl || undefined,
          trendingScore: 1.5, // Higher priority
          expiresAt
        }
      });
      
      // Mark as processed
      await prisma.trendingItem.update({
        where: { id: item.id },
        data: { isProcessed: true }
      });
      
      convertedCount++;
      console.log(`  ✓ Created international topic: "${topic.title.substring(0, 50)}..."`);
    } catch (error) {
      console.error(`  ✗ Failed to convert: ${item.headline}`, error);
      
      // Mark as processed to avoid retry loop
      await prisma.trendingItem.update({
        where: { id: item.id },
        data: { isProcessed: true }
      });
    }
  }
  
  console.log(`🌍 Converted ${convertedCount} international items to topics`);
  return convertedCount;
}

/**
 * Gets statistics about international topics
 */
export async function getInternationalStats(): Promise<{
  trendingItems: number;
  topicsInQueue: number;
  usedTopics: number;
}> {
  const [trendingItems, topicsInQueue, usedTopics] = await Promise.all([
    prisma.trendingItem.count({
      where: {
        sourceName: { startsWith: '[INTL]' },
        isProcessed: false
      }
    }),
    prisma.topicQueue.count({
      where: {
        topicType: 'INTERNATIONAL',
        isUsed: false
      }
    }),
    prisma.usedTopic.count({
      where: {
        topicType: 'INTERNATIONAL'
      }
    })
  ]);
  
  return { trendingItems, topicsInQueue, usedTopics };
}

/**
 * Picks an international topic for room creation
 */
export async function pickInternationalTopicForRoom(
  categoryId: string,
  language: 'English' | 'Hindi' = 'English'
): Promise<{
  title: string;
  description: string;
  sideALabel: string;
  sideBLabel: string;
} | null> {
  const topic = await prisma.topicQueue.findFirst({
    where: {
      categoryId,
      topicType: 'INTERNATIONAL',
      language,
      isUsed: false,
      OR: [
        { expiresAt: null },
        { expiresAt: { gt: new Date() } }
      ]
    },
    orderBy: { trendingScore: 'desc' }
  });
  
  if (!topic) return null;
  
  return {
    title: topic.title,
    description: topic.description || '',
    sideALabel: topic.sideALabel,
    sideBLabel: topic.sideBLabel
  };
}

/**
 * Full refresh of international topics
 * Run every 12 hours
 */
export async function refreshInternationalTopics(): Promise<void> {
  console.log('🌍 Starting international topics refresh...');
  
  try {
    // Fetch new international news
    await storeInternationalTrending();
    
    // Convert to debate topics
    await convertInternationalToTopics(15);
    
    // Log stats
    const stats = await getInternationalStats();
    console.log(`🌍 International stats: ${stats.trendingItems} pending, ${stats.topicsInQueue} in queue, ${stats.usedTopics} used`);
  } catch (error) {
    console.error('🌍 Failed to refresh international topics:', error);
  }
}
