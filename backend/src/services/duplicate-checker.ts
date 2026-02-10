import { createHash } from 'crypto';
import { prisma } from '../config/database.js';
import { TopicType } from '@prisma/client';

// Common words to remove for normalization
const STOP_WORDS = new Set([
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'vs', 'versus', 'or', 'and', 'but', 'if', 'then', 'than', 'that',
  'this', 'these', 'those', 'it', 'its', 'of', 'for', 'to', 'in', 'on',
  'at', 'by', 'with', 'about', 'against', 'between', 'into', 'through',
  'during', 'before', 'after', 'above', 'below', 'from', 'up', 'down',
  'out', 'off', 'over', 'under', 'again', 'further', 'once', 'here',
  'there', 'when', 'where', 'why', 'how', 'all', 'each', 'few', 'more',
  'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
  'same', 'so', 'can', 'will', 'just', 'should', 'now', 'क्या', 'है',
  'या', 'और', 'में', 'के', 'की', 'को', 'से', 'पर', 'ने', 'यह', 'वह',
  'कौन', 'बेहतर', 'better', 'best', 'worse', 'worst', 'who', 'which',
  'what', 'debate', 'discussion', 'topic'
]);

/**
 * Normalizes a topic title for duplicate detection
 * 1. Lowercase
 * 2. Remove punctuation
 * 3. Remove stop words
 * 4. Sort words alphabetically
 * 5. Join with single space
 */
export function normalizeTitle(title: string): string {
  // Lowercase
  let normalized = title.toLowerCase();
  
  // Remove punctuation and special characters
  normalized = normalized.replace(/[^\w\s\u0900-\u097F]/g, ' ');
  
  // Split into words
  const words = normalized.split(/\s+/).filter(word => word.length > 0);
  
  // Remove stop words
  const filteredWords = words.filter(word => !STOP_WORDS.has(word));
  
  // Sort alphabetically
  filteredWords.sort();
  
  // Join with single space
  return filteredWords.join(' ');
}

/**
 * Creates a SHA256 hash of the normalized title
 */
export function hashTitle(title: string): string {
  const normalized = normalizeTitle(title);
  return createHash('sha256').update(normalized).digest('hex');
}

/**
 * Checks if a topic title is a duplicate (used within last 3 months)
 * @param title The topic title to check
 * @returns true if duplicate, false if unique
 */
export async function isDuplicateTopic(title: string): Promise<boolean> {
  const titleHash = hashTitle(title);
  
  const existing = await prisma.usedTopic.findUnique({
    where: { titleHash }
  });
  
  return existing !== null;
}

/**
 * Checks if a topic is currently active (LIVE or SCHEDULED)
 * @param title The topic title to check
 * @returns true if active, false if not
 */
export async function isActiveTopic(title: string): Promise<boolean> {
  const normalizedTitle = normalizeTitle(title);
  
  // Get all active rooms
  const activeRooms = await prisma.room.findMany({
    where: {
      status: { in: ['LIVE', 'SCHEDULED'] }
    },
    select: { title: true }
  });
  
  // Check if any active room has similar title
  for (const room of activeRooms) {
    const roomNormalized = normalizeTitle(room.title);
    if (roomNormalized === normalizedTitle) {
      return true;
    }
  }
  
  return false;
}

/**
 * Checks if a topic can be used (not duplicate, not active)
 * @param title The topic title to check
 * @returns Object with canUse boolean and reason if cannot use
 */
export async function canUseTopic(title: string): Promise<{ canUse: boolean; reason?: string }> {
  // Check if it's an active topic
  if (await isActiveTopic(title)) {
    return { canUse: false, reason: 'Topic is currently active in a live or scheduled room' };
  }
  
  // Check if it's been used in last 3 months
  if (await isDuplicateTopic(title)) {
    return { canUse: false, reason: 'Topic was used within the last 3 months' };
  }
  
  return { canUse: true };
}

/**
 * Records a topic as used (add to UsedTopic table)
 * @param title The original topic title
 * @param categoryId The category ID
 * @param topicType The type of topic
 * @param language The language of the topic
 */
export async function recordTopicUsage(
  title: string,
  categoryId: string,
  topicType: TopicType,
  language: string = 'English'
): Promise<void> {
  const titleHash = hashTitle(title);
  const now = new Date();
  const expiresAt = new Date(now);
  expiresAt.setMonth(expiresAt.getMonth() + 3); // 3 months from now
  
  try {
    await prisma.usedTopic.upsert({
      where: { titleHash },
      update: {
        usedAt: now,
        expiresAt: expiresAt
      },
      create: {
        titleHash,
        originalTitle: title,
        categoryId,
        topicType,
        language,
        usedAt: now,
        expiresAt
      }
    });
    
    console.log(`📝 Recorded topic usage: "${title.substring(0, 50)}..." (expires: ${expiresAt.toISOString()})`);
  } catch (error) {
    console.error('Error recording topic usage:', error);
  }
}

/**
 * Cleans up expired UsedTopic entries (older than 3 months)
 * Should be run daily via scheduler
 */
export async function cleanupExpiredDuplicates(): Promise<number> {
  const now = new Date();
  
  const result = await prisma.usedTopic.deleteMany({
    where: {
      expiresAt: { lt: now }
    }
  });
  
  if (result.count > 0) {
    console.log(`🧹 Cleaned up ${result.count} expired used topics`);
  }
  
  return result.count;
}

/**
 * Gets statistics about used topics
 */
export async function getUsedTopicStats(): Promise<{
  total: number;
  byCategory: Record<string, number>;
  byType: Record<string, number>;
  byLanguage: Record<string, number>;
}> {
  const [total, byCategory, byType, byLanguage] = await Promise.all([
    prisma.usedTopic.count(),
    prisma.usedTopic.groupBy({
      by: ['categoryId'],
      _count: true
    }),
    prisma.usedTopic.groupBy({
      by: ['topicType'],
      _count: true
    }),
    prisma.usedTopic.groupBy({
      by: ['language'],
      _count: true
    })
  ]);
  
  return {
    total,
    byCategory: Object.fromEntries(byCategory.map(c => [c.categoryId, c._count])),
    byType: Object.fromEntries(byType.map(t => [t.topicType, t._count])),
    byLanguage: Object.fromEntries(byLanguage.map(l => [l.language, l._count]))
  };
}

/**
 * Batch check multiple titles for duplicates
 * @param titles Array of titles to check
 * @returns Map of title to isDuplicate boolean
 */
export async function batchCheckDuplicates(titles: string[]): Promise<Map<string, boolean>> {
  const hashes = titles.map(t => hashTitle(t));
  
  const existing = await prisma.usedTopic.findMany({
    where: {
      titleHash: { in: hashes }
    },
    select: { titleHash: true }
  });
  
  const existingSet = new Set(existing.map(e => e.titleHash));
  
  const result = new Map<string, boolean>();
  titles.forEach((title, index) => {
    result.set(title, existingSet.has(hashes[index]));
  });
  
  return result;
}
