/**
 * TrendingService - Fetches real-time trending news and converts them to debate topics
 * 
 * Data Sources:
 * 1. GNews API (free tier: 100 requests/day)
 * 2. Google News RSS (free, unlimited)
 * 3. Fallback: predefined trending topics
 * 
 * Flow:
 * 1. Fetch trending news from APIs/RSS
 * 2. Store as TrendingItems in database
 * 3. AI converts TrendingItems -> TopicQueue entries
 * 4. Topics have expiry, usage limits, and trending scores
 */

import { prisma } from '../config/database.js';
import { config } from '../config/index.js';
import Parser from 'rss-parser';

// Configure RSS parser with proper headers to avoid 403 errors
const rssParser = new Parser({
  headers: {
    'User-Agent': 'Mozilla/5.0 (compatible; BoloDebate/1.0; +https://bolo-debate.vercel.app)',
    'Accept': 'application/rss+xml, application/xml, text/xml, */*',
  },
  timeout: 10000, // 10 second timeout
});

// Region-specific news sources
interface NewsSource {
  name: string;
  rssUrl?: string;
  region?: string;  // null = national
  category?: string;
}

// Major Indian news RSS feeds organized by region
const NEWS_SOURCES: NewsSource[] = [
  // National sources
  { name: 'Times of India', rssUrl: 'https://timesofindia.indiatimes.com/rssfeedstopstories.cms', region: undefined },
  { name: 'NDTV', rssUrl: 'https://feeds.feedburner.com/ndtvnews-top-stories', region: undefined },
  { name: 'The Hindu', rssUrl: 'https://www.thehindu.com/news/national/feeder/default.rss', region: undefined },
  { name: 'Indian Express', rssUrl: 'https://indianexpress.com/section/india/feed/', region: undefined },
  { name: 'Hindustan Times', rssUrl: 'https://www.hindustantimes.com/feeds/rss/india-news/rssfeed.xml', region: undefined },
  
  // Category-specific
  { name: 'TOI Business', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/1898055.cms', category: 'Business' },
  { name: 'TOI Tech', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/66949542.cms', category: 'Technology' },
  { name: 'TOI Sports', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/4719148.cms', category: 'Sports' },
  { name: 'TOI Entertainment', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/1081479906.cms', category: 'Entertainment' },
  
  // Regional sources
  { name: 'TOI Mumbai', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/-2128838597.cms', region: 'Mumbai' },
  { name: 'TOI Delhi', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/-2128839596.cms', region: 'Delhi NCR' },
  { name: 'TOI Bangalore', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/-2128833038.cms', region: 'Bangalore' },
  { name: 'TOI Chennai', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/2950623.cms', region: 'Chennai' },
  { name: 'TOI Hyderabad', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/-2128816011.cms', region: 'Hyderabad' },
  { name: 'TOI Kolkata', rssUrl: 'https://timesofindia.indiatimes.com/rssfeeds/2950623.cms', region: 'Kolkata' },
];

// Category keywords for classification
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  Politics: ['election', 'government', 'minister', 'parliament', 'BJP', 'Congress', 'AAP', 'vote', 'policy', 'law', 'court', 'supreme', 'chief minister', 'PM', 'president', 'assembly', 'lok sabha', 'rajya sabha'],
  Business: ['economy', 'market', 'stock', 'sensex', 'nifty', 'company', 'startup', 'investment', 'RBI', 'bank', 'finance', 'rupee', 'GDP', 'inflation', 'tax', 'budget', 'revenue', 'profit'],
  Technology: ['AI', 'tech', 'software', 'app', 'digital', 'internet', 'cyber', 'startup', 'data', 'cloud', '5G', 'mobile', 'computer', 'IT', 'innovation', 'Google', 'Microsoft', 'Apple', 'Meta'],
  Sports: ['cricket', 'IPL', 'match', 'player', 'team', 'score', 'win', 'football', 'hockey', 'Olympic', 'sport', 'BCCI', 'tournament', 'championship', 'league', 'captain', 'coach'],
  Entertainment: ['movie', 'film', 'Bollywood', 'actor', 'actress', 'cinema', 'OTT', 'Netflix', 'music', 'concert', 'celebrity', 'star', 'director', 'song', 'album', 'award', 'show', 'series'],
};

interface TrendingItemData {
  headline: string;
  summary?: string;
  sourceUrl?: string;
  sourceName: string;
  publishedAt?: Date;
  regionName?: string;
  categoryName?: string;
}

/**
 * Classify a headline into a category based on keywords
 */
function classifyCategory(headline: string, summary?: string): string | undefined {
  const text = `${headline} ${summary || ''}`.toLowerCase();
  
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    for (const keyword of keywords) {
      if (text.includes(keyword.toLowerCase())) {
        return category;
      }
    }
  }
  
  return undefined;
}

/**
 * Calculate trending score based on recency and source reliability
 */
function calculateTrendingScore(publishedAt?: Date, sourceName?: string): number {
  let score = 1.0;
  
  // Recency boost: newer = higher score
  if (publishedAt) {
    const hoursAgo = (Date.now() - publishedAt.getTime()) / (1000 * 60 * 60);
    if (hoursAgo < 1) score += 0.5;
    else if (hoursAgo < 3) score += 0.3;
    else if (hoursAgo < 6) score += 0.2;
    else if (hoursAgo < 12) score += 0.1;
  }
  
  // Source reliability boost
  const reliableSources = ['Times of India', 'NDTV', 'The Hindu', 'Indian Express', 'Hindustan Times'];
  if (sourceName && reliableSources.some(s => sourceName.includes(s))) {
    score += 0.2;
  }
  
  return score;
}

/**
 * Fetch news from Google News RSS for India
 */
async function fetchGoogleNewsRSS(query?: string): Promise<TrendingItemData[]> {
  try {
    // Google News RSS for India
    const baseUrl = 'https://news.google.com/rss/search';
    const params = new URLSearchParams({
      q: query || 'India',
      hl: 'en-IN',
      gl: 'IN',
      ceid: 'IN:en',
    });
    
    const feed = await rssParser.parseURL(`${baseUrl}?${params}`);
    
    return feed.items.slice(0, 10).map(item => ({
      headline: item.title || 'Unknown',
      summary: item.contentSnippet,
      sourceUrl: item.link,
      sourceName: item.source?.title || 'Google News',
      publishedAt: item.pubDate ? new Date(item.pubDate) : undefined,
      categoryName: classifyCategory(item.title || '', item.contentSnippet),
    }));
  } catch (error) {
    console.error('Error fetching Google News RSS:', error);
    return [];
  }
}

/**
 * Fetch news from a specific RSS feed
 */
async function fetchRSSFeed(source: NewsSource): Promise<TrendingItemData[]> {
  if (!source.rssUrl) return [];
  
  try {
    const feed = await rssParser.parseURL(source.rssUrl);
    
    return feed.items.slice(0, 5).map(item => ({
      headline: item.title || 'Unknown',
      summary: item.contentSnippet || item.content,
      sourceUrl: item.link,
      sourceName: source.name,
      publishedAt: item.pubDate ? new Date(item.pubDate) : undefined,
      regionName: source.region,
      categoryName: source.category || classifyCategory(item.title || '', item.contentSnippet),
    }));
  } catch (error: unknown) {
    // Only log non-403 errors (403 is common for sites blocking bots)
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (!errorMessage.includes('403') && !errorMessage.includes('Status code')) {
      console.error(`Error fetching RSS from ${source.name}:`, errorMessage);
    }
    return [];
  }
}

/**
 * Fetch news from GNews API (if API key is available)
 */
async function fetchGNewsAPI(category?: string, region?: string): Promise<TrendingItemData[]> {
  if (!config.news.gnewsApiKey) {
    return [];
  }
  
  try {
    const params = new URLSearchParams({
      apikey: config.news.gnewsApiKey,
      lang: 'en',
      country: 'in',
      max: '10',
    });
    
    if (category) {
      params.set('topic', category.toLowerCase());
    }
    
    const response = await fetch(`https://gnews.io/api/v4/top-headlines?${params}`);
    
    if (!response.ok) {
      throw new Error(`GNews API error: ${response.status}`);
    }
    
    const data = await response.json() as { articles: Array<{
      title: string;
      description: string;
      url: string;
      source: { name: string };
      publishedAt: string;
    }> };
    
    return data.articles.map(article => ({
      headline: article.title,
      summary: article.description,
      sourceUrl: article.url,
      sourceName: article.source?.name || 'GNews',
      publishedAt: article.publishedAt ? new Date(article.publishedAt) : undefined,
      regionName: region,
      categoryName: category || classifyCategory(article.title, article.description),
    }));
  } catch (error) {
    console.error('Error fetching from GNews API:', error);
    return [];
  }
}

/**
 * Fetch all trending items from multiple sources
 */
export async function fetchTrendingItems(): Promise<TrendingItemData[]> {
  console.log('📰 Fetching trending news from multiple sources...');
  
  const allItems: TrendingItemData[] = [];
  
  // 1. Try GNews API first (if available)
  const gnewsItems = await fetchGNewsAPI();
  allItems.push(...gnewsItems);
  console.log(`  ✓ GNews API: ${gnewsItems.length} items`);
  
  // 2. Fetch from regional RSS feeds
  const rssPromises = NEWS_SOURCES.map(source => fetchRSSFeed(source));
  const rssResults = await Promise.allSettled(rssPromises);
  
  for (let i = 0; i < rssResults.length; i++) {
    const result = rssResults[i];
    if (result.status === 'fulfilled' && result.value.length > 0) {
      allItems.push(...result.value);
      console.log(`  ✓ ${NEWS_SOURCES[i].name}: ${result.value.length} items`);
    }
  }
  
  // 3. Fetch general Google News
  const googleItems = await fetchGoogleNewsRSS();
  allItems.push(...googleItems);
  console.log(`  ✓ Google News: ${googleItems.length} items`);
  
  // 4. Fetch category-specific Google News
  for (const category of ['Politics', 'Technology', 'Business', 'Sports']) {
    const categoryItems = await fetchGoogleNewsRSS(`India ${category}`);
    categoryItems.forEach(item => item.categoryName = category);
    allItems.push(...categoryItems);
    console.log(`  ✓ Google News ${category}: ${categoryItems.length} items`);
  }
  
  console.log(`📰 Total trending items fetched: ${allItems.length}`);
  
  return allItems;
}

/**
 * Store trending items in the database
 */
export async function storeTrendingItems(items: TrendingItemData[]): Promise<number> {
  // Get region and category IDs
  const regions = await prisma.region.findMany();
  const categories = await prisma.category.findMany();
  
  const regionMap = new Map(regions.map(r => [r.name, r.id]));
  const categoryMap = new Map(categories.map(c => [c.name, c.id]));
  
  // Default expiry: 24 hours from now
  const defaultExpiry = new Date(Date.now() + 24 * 60 * 60 * 1000);
  
  let stored = 0;
  
  for (const item of items) {
    // Skip items without headlines
    if (!item.headline || item.headline.length < 10) continue;
    
    // Check for duplicates (by headline similarity)
    const existing = await prisma.trendingItem.findFirst({
      where: {
        headline: item.headline,
        isProcessed: false,
      },
    });
    
    if (existing) continue;
    
    const regionId = item.regionName ? regionMap.get(item.regionName) : undefined;
    const categoryId = item.categoryName ? categoryMap.get(item.categoryName) : undefined;
    
    try {
      await prisma.trendingItem.create({
        data: {
          headline: item.headline,
          summary: item.summary,
          sourceUrl: item.sourceUrl,
          sourceName: item.sourceName,
          publishedAt: item.publishedAt,
          regionId,
          categoryId,
          trendingScore: calculateTrendingScore(item.publishedAt, item.sourceName),
          expiresAt: defaultExpiry,
        },
      });
      stored++;
    } catch (error) {
      // Ignore duplicate errors
      console.error('Error storing trending item:', error);
    }
  }
  
  console.log(`💾 Stored ${stored} new trending items`);
  return stored;
}

/**
 * Get unprocessed trending items for topic generation
 */
export async function getUnprocessedTrendingItems(limit: number = 20): Promise<Array<{
  id: string;
  headline: string;
  summary: string | null;
  sourceUrl: string | null;
  regionId: string | null;
  categoryId: string | null;
  trendingScore: number;
}>> {
  return prisma.trendingItem.findMany({
    where: {
      isProcessed: false,
      expiresAt: { gt: new Date() },
    },
    orderBy: { trendingScore: 'desc' },
    take: limit,
  });
}

/**
 * Mark trending items as processed
 */
export async function markTrendingItemsProcessed(ids: string[]): Promise<void> {
  await prisma.trendingItem.updateMany({
    where: { id: { in: ids } },
    data: { isProcessed: true },
  });
}

/**
 * Cleanup expired trending items
 */
export async function cleanupExpiredTrendingItems(): Promise<number> {
  const result = await prisma.trendingItem.deleteMany({
    where: {
      expiresAt: { lt: new Date() },
    },
  });
  
  console.log(`🗑️ Cleaned up ${result.count} expired trending items`);
  return result.count;
}

/**
 * Cleanup expired topics
 */
export async function cleanupExpiredTopics(): Promise<number> {
  const now = new Date();
  
  // Delete topics that are expired OR have exceeded max usages
  const result = await prisma.topicQueue.deleteMany({
    where: {
      OR: [
        { expiresAt: { lt: now } },
        {
          usageCount: { gte: 3 },  // Used 3+ times
          isUsed: true,
        },
      ],
    },
  });
  
  console.log(`🗑️ Cleaned up ${result.count} expired/overused topics`);
  return result.count;
}

/**
 * Update trending scores for existing topics based on current trends
 */
export async function refreshTopicTrendingScores(): Promise<void> {
  // Get current trending headlines
  const trendingItems = await prisma.trendingItem.findMany({
    where: {
      expiresAt: { gt: new Date() },
    },
    select: { headline: true, trendingScore: true },
  });
  
  const trendingKeywords = new Set<string>();
  trendingItems.forEach(item => {
    // Extract keywords from headlines
    const words = item.headline.toLowerCase().split(/\s+/);
    words.forEach(word => {
      if (word.length > 4) trendingKeywords.add(word);
    });
  });
  
  // Update topic scores based on keyword matches
  const topics = await prisma.topicQueue.findMany({
    where: { isUsed: false },
  });
  
  for (const topic of topics) {
    const titleWords = topic.title.toLowerCase().split(/\s+/);
    const matches = titleWords.filter(word => trendingKeywords.has(word)).length;
    
    // Boost score based on keyword matches
    const newScore = 1.0 + (matches * 0.2);
    
    if (Math.abs(topic.trendingScore - newScore) > 0.1) {
      await prisma.topicQueue.update({
        where: { id: topic.id },
        data: {
          trendingScore: newScore,
          lastRefreshedAt: new Date(),
        },
      });
    }
  }
  
  console.log(`🔄 Refreshed trending scores for ${topics.length} topics`);
}

/**
 * Main refresh function - called periodically
 */
export async function refreshTrendingData(): Promise<{
  fetched: number;
  stored: number;
  expiredCleaned: number;
}> {
  console.log('🔄 Starting trending data refresh...');
  
  // 1. Cleanup expired items first
  const expiredCleaned = await cleanupExpiredTrendingItems();
  await cleanupExpiredTopics();
  
  // 2. Fetch new trending items
  const items = await fetchTrendingItems();
  
  // 3. Store new items
  const stored = await storeTrendingItems(items);
  
  // 4. Refresh trending scores
  await refreshTopicTrendingScores();
  
  console.log('✅ Trending data refresh complete');
  
  return {
    fetched: items.length,
    stored,
    expiredCleaned,
  };
}
