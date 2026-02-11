/**
 * RatioEnforcer - Ensures balanced topic distribution
 * 
 * Targets:
 * - 50:50 Local (TRENDING) vs Generic (GENERIC + INTERNATIONAL) topics
 * - 50:50 Hindi vs English language
 * - No duplicate topics at any time
 * 
 * Uses simple alternating counters for strict 50:50 enforcement
 */

import { prisma } from '../config/database.js';
import { TopicType } from '@prisma/client';
import { canUseTopic, recordTopicUsage, isActiveTopic } from './duplicate-checker.js';
import { pickGenericTopicForRoom } from './generic-topics.js';
import { pickInternationalTopicForRoom } from './international.js';
import { translateTopicToHindi } from './ai.js';

// Ratio targets (as percentages)
const TARGET_RATIOS = {
  localVsGeneric: 0.5, // 50% local, 50% generic/international
  hindiVsEnglish: 0.5, // 50% Hindi, 50% English
};

// Tolerance for ratio enforcement (within 10% is acceptable)
const RATIO_TOLERANCE = 0.1;

// Simple counters for alternation (reset on server restart, but that's fine)
let topicTypeCounter = 0; // Even = trending, Odd = generic
let languageCounter = 0; // Even = English, Odd = Hindi

interface RoomDistribution {
  totalRooms: number;
  byLanguage: {
    Hindi: number;
    English: number;
  };
  byTopicType: {
    trending: number;
    generic: number;
    international: number;
  };
}

/**
 * Get current distribution of active (live + scheduled) rooms
 */
export async function getCurrentDistribution(): Promise<RoomDistribution> {
  const now = new Date();
  
  const activeRooms = await prisma.room.findMany({
    where: {
      status: { in: ['LIVE', 'SCHEDULED'] },
      scheduledAt: { lte: new Date(now.getTime() + 2 * 60 * 60 * 1000) } // Next 2 hours
    },
    select: {
      language: true,
      topicType: true, // Use Room's topicType directly
    }
  });
  
  const distribution: RoomDistribution = {
    totalRooms: activeRooms.length,
    byLanguage: {
      Hindi: 0,
      English: 0,
    },
    byTopicType: {
      trending: 0,
      generic: 0,
      international: 0,
    }
  };
  
  for (const room of activeRooms) {
    // Count language
    if (room.language === 'Hindi') {
      distribution.byLanguage.Hindi++;
    } else {
      distribution.byLanguage.English++;
    }
    
    // Use the room's topicType directly (no lookup needed)
    const topicType = room.topicType;
    
    if (topicType === 'TRENDING') {
      distribution.byTopicType.trending++;
    } else if (topicType === 'GENERIC') {
      distribution.byTopicType.generic++;
    } else if (topicType === 'INTERNATIONAL') {
      distribution.byTopicType.international++;
    } else {
      // Default to trending if null (legacy rooms)
      distribution.byTopicType.trending++;
    }
  }
  
  return distribution;
}

/**
 * Calculate what type of topic and language should be picked next
 * Uses simple alternation for strict 50:50 ratio
 */
export async function getNextTopicRequirements(): Promise<{
  preferredTopicType: 'local' | 'generic';
  preferredLanguage: 'Hindi' | 'English';
}> {
  // Simple alternation: even = local/trending, odd = generic
  const preferredTopicType: 'local' | 'generic' = 
    topicTypeCounter % 2 === 0 ? 'local' : 'generic';
  
  // Simple alternation: even = English, odd = Hindi
  const preferredLanguage: 'Hindi' | 'English' = 
    languageCounter % 2 === 0 ? 'English' : 'Hindi';
  
  // Increment counters for next call
  topicTypeCounter++;
  languageCounter++;
  
  console.log(`  📊 Counter state: topicType=${topicTypeCounter} (${preferredTopicType}), lang=${languageCounter} (${preferredLanguage})`);
  
  return { preferredTopicType, preferredLanguage };
}

// isTopicInActiveRooms is now handled by duplicate-checker.ts isActiveTopic()

/**
 * Pick a trending topic from the queue for the given category and region
 * Priority order:
 * 1. Region-specific + category match (best for regional rooms)
 * 2. Region-specific from any category
 * 3. Category match from any region
 * 4. Any trending topic
 */
async function pickTrendingTopic(categoryId: string, regionId?: string): Promise<{
  title: string;
  description: string;
  sideALabel: string;
  sideBLabel: string;
  topicId: string;
  topicRegionId?: string;
} | null> {
  const baseWhere = {
    isUsed: false,
    topicType: 'TRENDING' as const,
    OR: [
      { expiresAt: null },
      { expiresAt: { gt: new Date() } }
    ]
  };
  
  // Build search strategies in order of preference
  const searchStrategies: Array<{ where: any; description: string }> = [];
  
  if (regionId) {
    // 1. Region-specific + specific category (best match for regional rooms)
    searchStrategies.push({
      where: { ...baseWhere, categoryId, regionId },
      description: 'region + category'
    });
    // 2. Region-specific from any category
    searchStrategies.push({
      where: { ...baseWhere, regionId },
      description: 'region only'
    });
  }
  // 3. Specific category from any region
  searchStrategies.push({
    where: { ...baseWhere, categoryId },
    description: 'category only'
  });
  // 4. Any trending topic
  searchStrategies.push({
    where: baseWhere,
    description: 'any trending'
  });
  
  for (const strategy of searchStrategies) {
    const topics = await prisma.topicQueue.findMany({
      where: strategy.where,
      orderBy: { trendingScore: 'desc' },
      take: 20
    });
    
    if (topics.length === 0) continue;
    
    console.log(`    📰 Found ${topics.length} trending topics (${strategy.description})`);
    
    for (const topic of topics) {
      // Check for duplicates/similar topics in active rooms
      const isDuplicate = await isActiveTopic(topic.title);
      if (isDuplicate) {
        console.log(`    ⏭️ Skipping duplicate: ${topic.title.substring(0, 40)}...`);
        continue;
      }
      
      // Mark as used
      await prisma.topicQueue.update({
        where: { id: topic.id },
        data: { 
          isUsed: true,
          usageCount: { increment: 1 }
        }
      });
      
      console.log(`    ✅ Selected trending: ${topic.title.substring(0, 40)}...`);
      
      return {
        title: topic.title,
        description: topic.description || '',
        sideALabel: topic.sideALabel,
        sideBLabel: topic.sideBLabel,
        topicId: topic.id,
        topicRegionId: topic.regionId || undefined
      };
    }
  }
  
  console.log(`    ❌ No valid trending topics found`);
  return null;
}

/**
 * Pick the next topic for room creation based on ratio requirements
 * Uses strict alternation between trending and generic (50:50)
 * @param categoryId - The category to pick a topic for
 * @param regionId - Optional region ID to prioritize region-specific topics
 */
export async function pickBalancedTopic(
  categoryId: string,
  regionId?: string
): Promise<{
  title: string;
  originalTitle: string; // Always English, for duplicate checking
  description: string;
  sideALabel: string;
  sideBLabel: string;
  language: 'Hindi' | 'English';
  topicType: TopicType;
} | null> {
  const { preferredTopicType, preferredLanguage } = await getNextTopicRequirements();
  
  console.log(`  🎯 Picking topic: type=${preferredTopicType}, lang=${preferredLanguage}, region=${regionId || 'any'}`);
  
  let topic: {
    title: string;
    originalTitle?: string; // English title for duplicate checking
    description: string;
    sideALabel: string;
    sideBLabel: string;
  } | null = null;
  let selectedTopicType: TopicType = 'TRENDING';
  let englishOriginalTitle: string = '';
  
  // STRICT: Try preferred type, only fallback if absolutely none available
  if (preferredTopicType === 'local') {
    // Must try TRENDING first
    console.log(`  📰 Looking for TRENDING topic...`);
    const trendingResult = await pickTrendingTopic(categoryId, regionId);
    if (trendingResult) {
      topic = trendingResult;
      englishOriginalTitle = trendingResult.title; // Trending topics are in English
      selectedTopicType = 'TRENDING';
    } else {
      // Only fallback if no trending at all
      console.log(`  ⚠️ No trending available, fallback to generic`);
      const genericResult = await pickGenericTopicForRoom(categoryId, preferredLanguage);
      if (genericResult) {
        const isDupe = await isActiveTopic(genericResult.title, genericResult.originalTitle);
        if (isDupe) {
          topic = null;
        } else {
          topic = genericResult;
          englishOriginalTitle = genericResult.originalTitle;
          selectedTopicType = 'GENERIC';
        }
      }
    }
  } else {
    // Must try GENERIC first
    console.log(`  📚 Looking for GENERIC topic...`);
    const genericResult = await pickGenericTopicForRoom(categoryId, preferredLanguage);
    if (genericResult) {
      const isDupe = await isActiveTopic(genericResult.title, genericResult.originalTitle);
      if (isDupe) {
        console.log(`  ⚠️ Generic is duplicate, trying another`);
        topic = null;
      } else {
        topic = genericResult;
        englishOriginalTitle = genericResult.originalTitle;
        selectedTopicType = 'GENERIC';
      }
    }
    
    // Only fallback to trending if no generic
    if (!topic) {
      console.log(`  ⚠️ No generic available, fallback to trending`);
      const trendingResult = await pickTrendingTopic(categoryId, regionId);
      if (trendingResult) {
        topic = trendingResult;
        englishOriginalTitle = trendingResult.title;
        selectedTopicType = 'TRENDING';
      }
    }
  }
  
  if (!topic) {
    console.log(`  ❌ No topics available for category ${categoryId}`);
    return null;
  }
  
  // Use English original for duplicate checking
  const originalTitle = englishOriginalTitle || topic.title;
  
  // Final duplicate check using the English title
  const finalCheck = await isActiveTopic(topic.title, originalTitle);
  if (finalCheck) {
    console.log(`  ❌ Final check failed - duplicate topic`);
    return null;
  }
  
  // Translate to Hindi if needed (only for non-generic which already has Hindi)
  let finalTopic = { ...topic };
  if (preferredLanguage === 'Hindi' && selectedTopicType !== 'GENERIC') {
    console.log(`  🔄 Translating to Hindi...`);
    const translated = await translateTopicToHindi({
      title: topic.title,
      description: topic.description,
      sideALabel: topic.sideALabel,
      sideBLabel: topic.sideBLabel,
    });
    if (translated) {
      finalTopic = { ...topic, ...translated };
    }
  }
  
  // Record usage using original English title
  await recordTopicUsage(originalTitle, categoryId, selectedTopicType, preferredLanguage);
  
  console.log(`  ✅ Final: [${selectedTopicType}/${preferredLanguage}] ${finalTopic.title.substring(0, 40)}...`);
  
  return {
    title: finalTopic.title,
    originalTitle, // Always English
    description: finalTopic.description,
    sideALabel: finalTopic.sideALabel,
    sideBLabel: finalTopic.sideBLabel,
    language: preferredLanguage,
    topicType: selectedTopicType,
  };
}

/**
 * Get current ratio statistics
 */
export async function getRatioStats(): Promise<{
  distribution: RoomDistribution;
  localRatio: number;
  hindiRatio: number;
  isBalanced: boolean;
}> {
  const distribution = await getCurrentDistribution();
  
  const localCount = distribution.byTopicType.trending;
  const genericCount = distribution.byTopicType.generic + distribution.byTopicType.international;
  const totalTopicType = localCount + genericCount;
  
  const localRatio = totalTopicType > 0 ? localCount / totalTopicType : 0.5;
  const hindiRatio = distribution.totalRooms > 0 
    ? distribution.byLanguage.Hindi / distribution.totalRooms 
    : 0.5;
  
  const isLocalBalanced = Math.abs(localRatio - TARGET_RATIOS.localVsGeneric) <= RATIO_TOLERANCE;
  const isLanguageBalanced = Math.abs(hindiRatio - TARGET_RATIOS.hindiVsEnglish) <= RATIO_TOLERANCE;
  
  return {
    distribution,
    localRatio,
    hindiRatio,
    isBalanced: isLocalBalanced && isLanguageBalanced,
  };
}

/**
 * Rebalance existing topics if ratios are off
 * Called periodically by scheduler
 */
export async function rebalanceIfNeeded(): Promise<void> {
  const stats = await getRatioStats();
  
  if (stats.isBalanced) {
    console.log('✅ Topic ratios are balanced');
    return;
  }
  
  console.log(`⚠️ Topic ratios need rebalancing:`);
  console.log(`  Local ratio: ${(stats.localRatio * 100).toFixed(1)}% (target: 50%)`);
  console.log(`  Hindi ratio: ${(stats.hindiRatio * 100).toFixed(1)}% (target: 50%)`);
  
  // The next topic picks will naturally rebalance the ratios
  // through getNextTopicRequirements()
}
