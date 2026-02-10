import cron from 'node-cron';
import { prisma } from '../config/database.js';
import {
  checkAndStartScheduledRooms,
  checkAndEndExpiredRooms,
  sendEndingSoonWarning,
  ensureMinimumRoomsPerRegion,
  ensureMinimumRoomsPerCategory,
} from '../services/room.js';
import { generateBotMessage, generateTopicsFromTrending } from '../services/ai.js';
import { refreshTrendingData, cleanupExpiredTopics, cleanupExpiredTrendingItems } from '../services/trending.js';
import { broadcastToRoom } from '../websocket/index.js';
import { refreshInternationalTopics } from '../services/international.js';
import { ensureGenericTopicsInQueue, getGenericTopicStats } from '../services/generic-topics.js';
import { cleanupExpiredDuplicates, getUsedTopicStats } from '../services/duplicate-checker.js';
import { rebalanceIfNeeded, getRatioStats } from '../services/ratio-enforcer.js';

export function startScheduler(): void {
  console.log('✅ Starting scheduler...');

  // Check for rooms to start/end every 30 seconds
  cron.schedule('*/30 * * * * *', async () => {
    try {
      await checkAndStartScheduledRooms();
      await checkAndEndExpiredRooms();
      await cleanupStaleRooms();
    } catch (error) {
      console.error('Error in room lifecycle job:', error);
    }
  });

  // Send ending soon warnings every minute
  cron.schedule('* * * * *', async () => {
    try {
      await sendEndingSoonWarning();
    } catch (error) {
      console.error('Error in ending soon warning job:', error);
    }
  });

  // Ensure minimum rooms per region every 5 minutes
  cron.schedule('*/5 * * * *', async () => {
    try {
      await ensureMinimumRoomsPerRegion();
    } catch (error) {
      console.error('Error in ensure minimum rooms job:', error);
    }
  });

  // Ensure minimum rooms per category every 5 minutes (offset by 2.5 min from region check)
  cron.schedule('2-57/5 * * * *', async () => {
    try {
      await ensureMinimumRoomsPerCategory();
    } catch (error) {
      console.error('Error in ensure minimum rooms per category job:', error);
    }
  });

  // Send bot suggestions to active rooms every 3 minutes
  cron.schedule('*/3 * * * *', async () => {
    try {
      await sendBotSuggestions();
    } catch (error) {
      console.error('Error in bot suggestions job:', error);
    }
  });

  // ============================================
  // TRENDING TOPICS JOBS
  // ============================================

  // Refresh trending data every 2 hours (fetch new news)
  cron.schedule('0 */2 * * *', async () => {
    try {
      console.log('📰 Starting scheduled trending data refresh...');
      const result = await refreshTrendingData();
      console.log(`📰 Trending refresh: ${result.fetched} fetched, ${result.stored} stored`);
    } catch (error) {
      console.error('Error in trending data refresh job:', error);
    }
  });

  // Generate debate topics from trending items every hour
  cron.schedule('30 * * * *', async () => {
    try {
      console.log('🔄 Starting scheduled topic generation from trending...');
      const result = await generateTopicsFromTrending();
      console.log(`🔄 Topic generation: ${result.fetched} items, ${result.converted} topics created`);
    } catch (error) {
      console.error('Error in trending topic generation job:', error);
    }
  });

  // Clean up expired topics and trending items every 6 hours
  cron.schedule('0 */6 * * *', async () => {
    try {
      console.log('🗑️ Starting scheduled cleanup...');
      const expiredTopics = await cleanupExpiredTopics();
      const expiredTrending = await cleanupExpiredTrendingItems();
      const expiredDuplicates = await cleanupExpiredDuplicates();
      console.log(`🗑️ Cleanup: ${expiredTopics} topics, ${expiredTrending} trending, ${expiredDuplicates} duplicate records removed`);
    } catch (error) {
      console.error('Error in cleanup job:', error);
    }
  });

  // ============================================
  // NEW TOPIC SYSTEM JOBS
  // ============================================

  // Refresh international topics every 12 hours
  cron.schedule('0 */12 * * *', async () => {
    try {
      console.log('🌍 Starting scheduled international topics refresh...');
      await refreshInternationalTopics();
    } catch (error) {
      console.error('Error in international topics refresh job:', error);
    }
  });

  // Ensure generic topics are available every 4 hours
  cron.schedule('0 */4 * * *', async () => {
    try {
      console.log('📚 Ensuring generic topics in queue...');
      const added = await ensureGenericTopicsInQueue();
      const stats = await getGenericTopicStats();
      console.log(`📚 Generic topics: ${added} added, ${stats.inQueue} in queue, ${stats.usedInLast3Months} used recently`);
    } catch (error) {
      console.error('Error in generic topics job:', error);
    }
  });

  // Check ratio balance every 15 minutes
  cron.schedule('*/15 * * * *', async () => {
    try {
      await rebalanceIfNeeded();
      const stats = await getRatioStats();
      console.log(`📊 Ratio check: Local ${(stats.localRatio * 100).toFixed(0)}%, Hindi ${(stats.hindiRatio * 100).toFixed(0)}%, Balanced: ${stats.isBalanced}`);
    } catch (error) {
      console.error('Error in ratio rebalancing job:', error);
    }
  });

  // Log topic system stats every hour
  cron.schedule('45 * * * *', async () => {
    try {
      const usedStats = await getUsedTopicStats();
      const genericStats = await getGenericTopicStats();
      const ratioStats = await getRatioStats();
      
      console.log('📈 Topic System Stats:');
      console.log(`  - Used topics (3mo): ${usedStats.total} total, ${usedStats.byType.TRENDING || 0} trending, ${usedStats.byType.GENERIC || 0} generic, ${usedStats.byType.INTERNATIONAL || 0} international`);
      console.log(`  - Generic pool: ${genericStats.totalPredefined} predefined, ${genericStats.inQueue} in queue`);
      console.log(`  - Active rooms: ${ratioStats.distribution.totalRooms}, Local: ${(ratioStats.localRatio * 100).toFixed(0)}%, Hindi: ${(ratioStats.hindiRatio * 100).toFixed(0)}%`);
    } catch (error) {
      console.error('Error in stats logging job:', error);
    }
  });

  // Run initial setup on startup (after 30 seconds to let the server stabilize)
  setTimeout(async () => {
    try {
      console.log('🚀 Running initial topic system setup...');
      
      // 1. Fetch trending data
      console.log('📰 Fetching trending data...');
      const trendingResult = await generateTopicsFromTrending();
      console.log(`📰 Trending: ${trendingResult.fetched} items, ${trendingResult.converted} topics`);
      
      // 2. Ensure generic topics are available
      console.log('📚 Loading generic topics...');
      const genericAdded = await ensureGenericTopicsInQueue();
      console.log(`📚 Generic: ${genericAdded} topics added to queue`);
      
      // 3. Fetch international topics
      console.log('🌍 Fetching international topics...');
      await refreshInternationalTopics();
      
      // 4. Ensure category coverage
      console.log('📚 Ensuring category coverage...');
      await ensureMinimumRoomsPerCategory();
      
      // 5. Log final stats
      const stats = await getRatioStats();
      console.log(`✅ Initial setup complete. Active rooms: ${stats.distribution.totalRooms}`);
      console.log(`   Local: ${(stats.localRatio * 100).toFixed(0)}%, Hindi: ${(stats.hindiRatio * 100).toFixed(0)}%`);
    } catch (error) {
      console.error('Error in initial topic system setup:', error);
    }
  }, 30000);

  console.log('Scheduler started with the following jobs:');
  console.log('  - Room lifecycle check: every 30 seconds');
  console.log('  - Ending soon warnings: every minute');
  console.log('  - Ensure minimum rooms (region): every 5 minutes');
  console.log('  - Ensure minimum rooms (category): every 5 minutes (offset)');
  console.log('  - Bot suggestions: every 3 minutes');
  console.log('  - Ratio balance check: every 15 minutes');
  console.log('  - Trending data refresh: every 2 hours');
  console.log('  - Generic topics refresh: every 4 hours');
  console.log('  - Cleanup expired topics: every 6 hours');
  console.log('  - International topics refresh: every 12 hours');
  console.log('  - Topic generation from trending: every hour');
  console.log('  - Topic system stats: every hour');
}

async function sendBotSuggestions(): Promise<void> {
  // Get all live rooms
  const liveRooms = await prisma.room.findMany({
    where: { status: 'LIVE' },
    select: {
      id: true,
      title: true,
      sideALabel: true,
      sideBLabel: true,
      type: true,
    },
  });

  for (const room of liveRooms) {
    // Only send suggestions to debate rooms
    if (room.type !== 'DEBATE' || !room.sideALabel || !room.sideBLabel) {
      continue;
    }

    try {
      const suggestion = await generateBotMessage(
        room.id,
        room.title,
        room.sideALabel,
        room.sideBLabel
      );

      if (suggestion) {
        // Save bot message to database
        const message = await prisma.message.create({
          data: {
            roomId: room.id,
            userId: 'bot', // Special bot user ID
            content: suggestion,
            isBot: true,
          },
        });

        // Broadcast to room
        broadcastToRoom(room.id, {
          type: 'ai:suggestion',
          roomId: room.id,
          payload: {
            id: message.id,
            content: suggestion,
            isBot: true,
            createdAt: message.createdAt.toISOString(),
          },
          timestamp: new Date().toISOString(),
        });
      }
    } catch (error) {
      console.error(`Error sending bot suggestion to room ${room.id}:`, error);
    }
  }
}

// Clean up stale rooms
// Room policy: 30 min base + max 3 extensions of 5 min = 45 min absolute max
async function cleanupStaleRooms(): Promise<void> {
  const maxRoomTime = 45 * 60 * 1000; // 45 minutes absolute max (30 base + 15 extensions)
  const cutoffTime = new Date(Date.now() - maxRoomTime);
  
  // Find any room that has been live longer than 45 minutes
  // This is a safety net - rooms should normally end via endsAt check
  const staleRooms = await prisma.room.findMany({
    where: {
      status: 'LIVE',
      startedAt: { lte: cutoffTime },
    },
    select: { id: true, title: true, startedAt: true },
  });
  
  if (staleRooms.length > 0) {
    console.log(`Cleaning up ${staleRooms.length} stale rooms (exceeded 45 min max)`);
    
    for (const room of staleRooms) {
      try {
        await prisma.room.update({
          where: { id: room.id },
          data: { status: 'ENDED' },
        });
        
        await prisma.roomParticipant.updateMany({
          where: { roomId: room.id, leftAt: null },
          data: { leftAt: new Date() },
        });
        
        broadcastToRoom(room.id, {
          type: 'room:ended',
          roomId: room.id,
          payload: {},
          timestamp: new Date().toISOString(),
        });
        
        console.log(`Ended stale room: ${room.id} (${room.title})`);
      } catch (error) {
        console.error(`Error ending stale room ${room.id}:`, error);
      }
    }
  }
}
