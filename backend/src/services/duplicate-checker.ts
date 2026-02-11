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
  'what', 'debate', 'discussion', 'topic', 'चाहिए', 'होना', 'करना',
  'करें', 'करे', 'होनी', 'होने', 'जाना', 'जाए', 'जाएं', 'रहा', 'रही',
  'कर', 'हो', 'था', 'थी', 'थे', 'हैं', 'हुआ', 'हुई', 'हुए', 'गया', 'गई'
]);

// Hindi-English equivalents for semantic matching
const WORD_EQUIVALENTS: Record<string, string> = {
  // Public/सार्वजनिक/पब्लिक
  'सार्वजनिक': 'public',
  'पब्लिक': 'public',
  'public': 'public',
  // Criticism/आलोचना/क्रिटिसिज़्म
  'आलोचना': 'criticism',
  'क्रिटिसिज़्म': 'criticism',
  'criticism': 'criticism',
  // Budget/बजट
  'बजट': 'budget',
  'budget': 'budget',
  // Allocation/आवंटन
  'आवंटन': 'allocation',
  'allocation': 'allocation',
  // Change/बदलना/बदला/बदलाव
  'बदलना': 'change',
  'बदला': 'change',
  'बदलाव': 'change',
  'change': 'change',
  // Response/जवाब
  'जवाब': 'response',
  'response': 'response',
  // Hero/हीरो/नायक
  'हीरो': 'hero',
  'hero': 'hero',
  'नायक': 'hero',
  // Celebrity/सेलिब्रिटी/सेलिब्रिटीज़
  'सेलिब्रिटी': 'celebrity',
  'सेलिब्रिटीज़': 'celebrity',
  'celebrity': 'celebrity',
  'celebrities': 'celebrity',
  // Social/सामाजिक
  'सामाजिक': 'social',
  'social': 'social',
  // Cause/कारण
  'कारण': 'cause',
  'कारणों': 'cause',
  'cause': 'cause',
  // Influence/प्रभाव
  'प्रभाव': 'influence',
  'influence': 'influence',
  // India/भारत
  'भारत': 'india',
  'india': 'india',
  'indian': 'india',
  // Short/छोटा/शॉर्ट
  'छोटा': 'short',
  'short': 'short',
  'शॉर्ट': 'short',
  // Video/वीडियो
  'वीडियो': 'video',
  'video': 'video',
  'videos': 'video',
  // Attention/ध्यान
  'ध्यान': 'attention',
  'attention': 'attention',
};

/**
 * Normalizes a word using equivalents map
 */
function normalizeWord(word: string): string {
  const lower = word.toLowerCase();
  return WORD_EQUIVALENTS[lower] || lower;
}

/**
 * Extracts key content words from title (removes stop words, normalizes equivalents)
 */
export function extractKeyWords(title: string): string[] {
  // Remove punctuation and special characters
  let cleaned = title.toLowerCase().replace(/[^\w\s\u0900-\u097F]/g, ' ');
  
  // Split into words
  const words = cleaned.split(/\s+/).filter(word => word.length > 1);
  
  // Remove stop words and normalize
  const keyWords = words
    .filter(word => !STOP_WORDS.has(word))
    .map(word => normalizeWord(word));
  
  return [...new Set(keyWords)]; // Remove duplicates
}

/**
 * Normalizes a topic title for duplicate detection
 * 1. Extract key words
 * 2. Normalize equivalents (Hindi/English)
 * 3. Sort alphabetically
 * 4. Join with single space
 */
export function normalizeTitle(title: string): string {
  const keyWords = extractKeyWords(title);
  keyWords.sort();
  return keyWords.join(' ');
}

/**
 * Calculate similarity between two titles (0-1)
 * Uses Jaccard similarity on key words
 */
export function calculateSimilarity(title1: string, title2: string): number {
  const words1 = new Set(extractKeyWords(title1));
  const words2 = new Set(extractKeyWords(title2));
  
  if (words1.size === 0 || words2.size === 0) return 0;
  
  const intersection = new Set([...words1].filter(x => words2.has(x)));
  const union = new Set([...words1, ...words2]);
  
  return intersection.size / union.size;
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
 * Uses fuzzy matching to catch semantic duplicates
 * Checks against both title and originalTitle to catch translated versions
 * @param title The topic title to check (should be English for best results)
 * @param originalEnglishTitle Optional - the English version of the title for cross-language matching
 * @returns true if active (or similar topic is active), false if not
 */
export async function isActiveTopic(
  title: string, 
  originalEnglishTitle?: string
): Promise<boolean> {
  const SIMILARITY_THRESHOLD = 0.5; // 50% word overlap = duplicate
  
  // Get all active rooms with both title and originalTitle
  const activeRooms = await prisma.room.findMany({
    where: {
      status: { in: ['LIVE', 'SCHEDULED'] }
    },
    select: { title: true, originalTitle: true }
  });
  
  // Collect all titles to check against (both the input and its English original)
  const titlesToCheck = [title];
  if (originalEnglishTitle && originalEnglishTitle !== title) {
    titlesToCheck.push(originalEnglishTitle);
  }
  
  for (const room of activeRooms) {
    // Collect all titles from the existing room
    const existingTitles = [room.title];
    if (room.originalTitle && room.originalTitle !== room.title) {
      existingTitles.push(room.originalTitle);
    }
    
    // Check all combinations
    for (const newTitle of titlesToCheck) {
      for (const existingTitle of existingTitles) {
        const similarity = calculateSimilarity(newTitle, existingTitle);
        if (similarity >= SIMILARITY_THRESHOLD) {
          console.log(`    ⚠️ Similar topic found (${(similarity * 100).toFixed(0)}% match):`);
          console.log(`       New: "${newTitle.substring(0, 50)}..."`);
          console.log(`       Existing: "${existingTitle.substring(0, 50)}..."`);
          return true;
        }
      }
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
