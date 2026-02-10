import { prisma } from '../config/database.js';
import { TopicType } from '@prisma/client';
import { canUseTopic, hashTitle } from './duplicate-checker.js';
import genericTopicsData from '../data/generic-topics.json' with { type: 'json' };

interface GenericTopic {
  id: string;
  category: string;
  title: string;
  titleHindi: string;
  sideA: string;
  sideB: string;
  sideAHindi: string;
  sideBHindi: string;
  tags: string[];
}

// Map category names to their IDs (cached)
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
 * Gets all predefined generic topics
 */
export function getAllGenericTopics(): GenericTopic[] {
  return genericTopicsData.topics as GenericTopic[];
}

/**
 * Gets generic topics for a specific category
 */
export function getGenericTopicsByCategory(categoryName: string): GenericTopic[] {
  return getAllGenericTopics().filter(t => t.category === categoryName);
}

/**
 * Gets a random unused generic topic for a category and language
 * Checks against UsedTopic table to prevent duplicates within 3 months
 */
export async function getAvailableGenericTopic(
  categoryName: string,
  language: 'English' | 'Hindi' = 'English'
): Promise<GenericTopic | null> {
  const topics = getGenericTopicsByCategory(categoryName);
  
  if (topics.length === 0) {
    console.log(`No generic topics found for category: ${categoryName}`);
    return null;
  }
  
  // Shuffle topics to randomize selection
  const shuffled = [...topics].sort(() => Math.random() - 0.5);
  
  // Find first available (not used in last 3 months)
  for (const topic of shuffled) {
    const title = language === 'Hindi' ? topic.titleHindi : topic.title;
    const { canUse } = await canUseTopic(title);
    
    if (canUse) {
      return topic;
    }
  }
  
  console.log(`All generic topics for ${categoryName} have been used in last 3 months`);
  return null;
}

/**
 * Adds a generic topic to the TopicQueue
 * @param markAsUsed - if true, marks the topic as used immediately (for room creation)
 */
export async function addGenericTopicToQueue(
  topic: GenericTopic,
  language: 'English' | 'Hindi' = 'English',
  markAsUsed: boolean = false
): Promise<void> {
  const categoryMap = await getCategoryIdMap();
  const categoryId = categoryMap.get(topic.category);
  
  if (!categoryId) {
    console.error(`Category not found: ${topic.category}`);
    return;
  }
  
  const title = language === 'Hindi' ? topic.titleHindi : topic.title;
  const sideA = language === 'Hindi' ? topic.sideAHindi : topic.sideA;
  const sideB = language === 'Hindi' ? topic.sideBHindi : topic.sideB;
  
  // Check duplicate
  const { canUse, reason } = await canUseTopic(title);
  if (!canUse) {
    console.log(`Cannot add generic topic: ${reason}`);
    return;
  }
  
  // Set expiry to 30 days for generic topics (they're evergreen, just rotate)
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30);
  
  await prisma.topicQueue.create({
    data: {
      categoryId,
      title,
      description: `A classic debate topic for ${topic.category}`,
      sideALabel: sideA,
      sideBLabel: sideB,
      topicType: 'GENERIC',
      language,
      regionTags: ['National'], // Generic topics are national-level
      trendingScore: 0.5, // Lower priority than trending topics
      isUsed: markAsUsed,
      usageCount: markAsUsed ? 1 : 0,
      expiresAt
    }
  });
  
  console.log(`📚 Added generic topic to queue: "${title.substring(0, 50)}..." (${language})${markAsUsed ? ' [USED]' : ''}`);
}

/**
 * Ensures there are enough generic topics in the queue for each category
 * Target: At least 2 generic topics per category (1 English, 1 Hindi)
 */
export async function ensureGenericTopicsInQueue(): Promise<number> {
  const categoryMap = await getCategoryIdMap();
  let addedCount = 0;
  
  for (const [categoryName, categoryId] of categoryMap) {
    // Count existing unused generic topics for this category
    const existingCount = await prisma.topicQueue.count({
      where: {
        categoryId,
        topicType: 'GENERIC',
        isUsed: false
      }
    });
    
    // We want at least 2 per category (1 English, 1 Hindi)
    if (existingCount < 2) {
      const needed = 2 - existingCount;
      
      // Alternate between English and Hindi
      const languages: ('English' | 'Hindi')[] = ['English', 'Hindi'];
      
      for (let i = 0; i < needed; i++) {
        const language = languages[i % 2];
        const topic = await getAvailableGenericTopic(categoryName, language);
        
        if (topic) {
          await addGenericTopicToQueue(topic, language);
          addedCount++;
        }
      }
    }
  }
  
  if (addedCount > 0) {
    console.log(`📚 Added ${addedCount} generic topics to queue`);
  }
  
  return addedCount;
}

/**
 * Gets statistics about generic topics usage
 */
export async function getGenericTopicStats(): Promise<{
  totalPredefined: number;
  inQueue: number;
  usedInLast3Months: number;
  byCategory: Record<string, { predefined: number; inQueue: number }>;
}> {
  const allTopics = getAllGenericTopics();
  const categoryMap = await getCategoryIdMap();
  
  // Count by category
  const byCategory: Record<string, { predefined: number; inQueue: number }> = {};
  
  for (const [categoryName, categoryId] of categoryMap) {
    const predefined = allTopics.filter(t => t.category === categoryName).length;
    const inQueue = await prisma.topicQueue.count({
      where: {
        categoryId,
        topicType: 'GENERIC',
        isUsed: false
      }
    });
    
    byCategory[categoryName] = { predefined, inQueue };
  }
  
  const inQueueTotal = await prisma.topicQueue.count({
    where: {
      topicType: 'GENERIC',
      isUsed: false
    }
  });
  
  const usedInLast3Months = await prisma.usedTopic.count({
    where: {
      topicType: 'GENERIC'
    }
  });
  
  return {
    totalPredefined: allTopics.length,
    inQueue: inQueueTotal,
    usedInLast3Months,
    byCategory
  };
}

/**
 * Generates new generic topics using AI (for expanding the pool)
 * This is a placeholder for future AI-based topic generation
 * Currently, we rely on the predefined list in generic-topics.json
 */
export async function generateNewGenericTopicsWithAI(
  categoryName: string,
  count: number = 5
): Promise<void> {
  console.log(`🤖 AI generic topic generation for ${categoryName} (${count} topics) - PLACEHOLDER`);
  console.log('   Currently using predefined topics from generic-topics.json');
  console.log('   To expand, add more topics to the JSON file');
  
  // Future implementation would:
  // 1. Call AI service with prompts for evergreen debate topics
  // 2. Validate generated topics for debate suitability
  // 3. Add to database or JSON file for future use
}

/**
 * Validates that all categories have sufficient generic topics
 * Returns a report of category coverage
 */
export async function validateCategoryCoverage(): Promise<{
  isComplete: boolean;
  categories: Array<{
    name: string;
    predefinedCount: number;
    inQueueCount: number;
    hasMinimum: boolean;
    recommendation: string | null;
  }>;
}> {
  const MINIMUM_TOPICS_PER_CATEGORY = 10;
  
  const categoryMap = await getCategoryIdMap();
  const allTopics = getAllGenericTopics();
  
  const categories: Array<{
    name: string;
    predefinedCount: number;
    inQueueCount: number;
    hasMinimum: boolean;
    recommendation: string | null;
  }> = [];
  
  for (const [categoryName, categoryId] of categoryMap) {
    const predefinedCount = allTopics.filter(t => t.category === categoryName).length;
    const inQueueCount = await prisma.topicQueue.count({
      where: {
        categoryId,
        topicType: 'GENERIC',
        isUsed: false
      }
    });
    
    const hasMinimum = predefinedCount >= MINIMUM_TOPICS_PER_CATEGORY;
    
    categories.push({
      name: categoryName,
      predefinedCount,
      inQueueCount,
      hasMinimum,
      recommendation: hasMinimum 
        ? null 
        : `Add ${MINIMUM_TOPICS_PER_CATEGORY - predefinedCount} more topics to generic-topics.json`
    });
  }
  
  const isComplete = categories.every(c => c.hasMinimum);
  
  return { isComplete, categories };
}

/**
 * Gets categories that need more generic topics
 */
export function getCategoriesNeedingTopics(): string[] {
  const categoryMap = new Map<string, number>();
  const allTopics = getAllGenericTopics();
  
  // Count topics per category
  for (const topic of allTopics) {
    const count = categoryMap.get(topic.category) || 0;
    categoryMap.set(topic.category, count + 1);
  }
  
  // Return categories with less than 10 topics
  const needsMore: string[] = [];
  for (const [category, count] of categoryMap) {
    if (count < 10) {
      needsMore.push(category);
    }
  }
  
  return needsMore;
}

/**
 * Picks a generic topic for room creation
 * Returns null if no suitable topic is available
 * Marks topic as used to prevent duplicates
 */
export async function pickGenericTopicForRoom(
  categoryId: string,
  language: 'English' | 'Hindi' = 'English'
): Promise<{
  title: string;
  description: string;
  sideALabel: string;
  sideBLabel: string;
} | null> {
  // First try to get from queue
  const queuedTopic = await prisma.topicQueue.findFirst({
    where: {
      categoryId,
      topicType: 'GENERIC',
      language,
      isUsed: false,
      OR: [
        { expiresAt: null },
        { expiresAt: { gt: new Date() } }
      ]
    },
    orderBy: { createdAt: 'asc' } // FIFO
  });
  
  if (queuedTopic) {
    // Mark as used immediately to prevent duplicates
    await prisma.topicQueue.update({
      where: { id: queuedTopic.id },
      data: { 
        isUsed: true,
        usageCount: { increment: 1 }
      }
    });
    
    return {
      title: queuedTopic.title,
      description: queuedTopic.description || '',
      sideALabel: queuedTopic.sideALabel,
      sideBLabel: queuedTopic.sideBLabel
    };
  }
  
  // If not in queue, try to find from predefined list
  const categories = await prisma.category.findMany({
    where: { id: categoryId },
    select: { name: true }
  });
  
  if (categories.length === 0) return null;
  
  const categoryName = categories[0].name;
  const topic = await getAvailableGenericTopic(categoryName, language);
  
  if (topic) {
    // Add to queue and mark as used immediately for room creation
    await addGenericTopicToQueue(topic, language, true);
    
    return {
      title: language === 'Hindi' ? topic.titleHindi : topic.title,
      description: `A classic debate topic for ${categoryName}`,
      sideALabel: language === 'Hindi' ? topic.sideAHindi : topic.sideA,
      sideBLabel: language === 'Hindi' ? topic.sideBHindi : topic.sideB
    };
  }
  
  return null;
}
