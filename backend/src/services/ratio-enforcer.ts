/**
 * RatioEnforcer - Ensures balanced topic distribution
 * 
 * Targets:
 * - 50:50 Local (TRENDING) vs Generic (GENERIC + INTERNATIONAL) topics
 * - 50:50 Hindi vs English language
 * - No duplicate topics at any time
 */

import { prisma } from '../config/database.js';
import { TopicType } from '@prisma/client';
import { canUseTopic, recordTopicUsage } from './duplicate-checker.js';
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
      title: true,
    }
  });
  
  // Get topic types from TopicQueue based on titles
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
    
    // Try to find topic type from queue (approximate by checking if topic exists in queue)
    const topic = await prisma.topicQueue.findFirst({
      where: { title: room.title },
      select: { topicType: true }
    });
    
    if (topic) {
      if (topic.topicType === 'TRENDING') {
        distribution.byTopicType.trending++;
      } else if (topic.topicType === 'GENERIC') {
        distribution.byTopicType.generic++;
      } else {
        distribution.byTopicType.international++;
      }
    } else {
      // Default to trending if not found in queue
      distribution.byTopicType.trending++;
    }
  }
  
  return distribution;
}

/**
 * Calculate what type of topic and language should be picked next
 */
export async function getNextTopicRequirements(): Promise<{
  preferredTopicType: 'local' | 'generic';
  preferredLanguage: 'Hindi' | 'English';
}> {
  const dist = await getCurrentDistribution();
  
  // Calculate current ratios
  const localCount = dist.byTopicType.trending;
  const genericCount = dist.byTopicType.generic + dist.byTopicType.international;
  const totalTopicType = localCount + genericCount;
  
  const localRatio = totalTopicType > 0 ? localCount / totalTopicType : 0.5;
  const hindiRatio = dist.totalRooms > 0 
    ? dist.byLanguage.Hindi / dist.totalRooms 
    : 0.5;
  
  // Determine what's needed to balance ratios
  const preferredTopicType: 'local' | 'generic' = 
    localRatio > TARGET_RATIOS.localVsGeneric + RATIO_TOLERANCE ? 'generic' :
    localRatio < TARGET_RATIOS.localVsGeneric - RATIO_TOLERANCE ? 'local' :
    Math.random() < 0.5 ? 'local' : 'generic';
  
  const preferredLanguage: 'Hindi' | 'English' = 
    hindiRatio > TARGET_RATIOS.hindiVsEnglish + RATIO_TOLERANCE ? 'English' :
    hindiRatio < TARGET_RATIOS.hindiVsEnglish - RATIO_TOLERANCE ? 'Hindi' :
    Math.random() < 0.5 ? 'Hindi' : 'English';
  
  return { preferredTopicType, preferredLanguage };
}

/**
 * Pick the next topic for room creation based on ratio requirements
 */
export async function pickBalancedTopic(
  categoryId: string,
  regionTags: string[] = ['National']
): Promise<{
  title: string;
  description: string;
  sideALabel: string;
  sideBLabel: string;
  language: 'Hindi' | 'English';
  topicType: TopicType;
} | null> {
  const { preferredTopicType, preferredLanguage } = await getNextTopicRequirements();
  
  let topic: {
    title: string;
    description: string;
    sideALabel: string;
    sideBLabel: string;
  } | null = null;
  let selectedTopicType: TopicType = 'TRENDING';
  
  // Try to get preferred topic type first
  if (preferredTopicType === 'generic') {
    // Try generic first
    topic = await pickGenericTopicForRoom(categoryId, preferredLanguage);
    if (topic) {
      selectedTopicType = 'GENERIC';
    } else {
      // Fallback to international
      topic = await pickInternationalTopicForRoom(categoryId, preferredLanguage);
      if (topic) {
        selectedTopicType = 'INTERNATIONAL';
      }
    }
  }
  
  // If no generic/international found, or if local is preferred
  if (!topic) {
    // Try trending topic from queue
    const trendingTopic = await prisma.topicQueue.findFirst({
      where: {
        categoryId,
        topicType: 'TRENDING',
        isUsed: false,
        AND: [
          {
            OR: [
              { expiresAt: null },
              { expiresAt: { gt: new Date() } }
            ]
          },
          {
            OR: [
              { regionTags: { hasSome: regionTags } },
              { regionTags: { isEmpty: true } }
            ]
          }
        ]
      },
      orderBy: { trendingScore: 'desc' }
    });
    
    if (trendingTopic) {
      // Check for duplicates
      const { canUse } = await canUseTopic(trendingTopic.title);
      if (canUse) {
        topic = {
          title: trendingTopic.title,
          description: trendingTopic.description || '',
          sideALabel: trendingTopic.sideALabel,
          sideBLabel: trendingTopic.sideBLabel,
        };
        selectedTopicType = 'TRENDING';
        
        // Mark as used
        await prisma.topicQueue.update({
          where: { id: trendingTopic.id },
          data: { 
            isUsed: true,
            usageCount: { increment: 1 }
          }
        });
      }
    }
  }
  
  // If still no topic, try any available from queue
  if (!topic) {
    // Try any generic topic
    topic = await pickGenericTopicForRoom(categoryId, preferredLanguage);
    if (topic) {
      selectedTopicType = 'GENERIC';
    }
  }
  
  if (!topic) {
    console.log(`⚠️ No topics available for category ${categoryId}`);
    return null;
  }
  
  // Get final topic content
  let finalTopic = { ...topic };
  const finalLanguage = preferredLanguage;
  
  // Translate to Hindi if needed
  if (finalLanguage === 'Hindi' && selectedTopicType !== 'GENERIC') {
    // Generic topics already have Hindi translations in the JSON
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
  
  // Record usage to prevent duplicates
  await recordTopicUsage(topic.title, categoryId, selectedTopicType, finalLanguage);
  
  return {
    title: finalTopic.title,
    description: finalTopic.description,
    sideALabel: finalTopic.sideALabel,
    sideBLabel: finalTopic.sideBLabel,
    language: finalLanguage,
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
