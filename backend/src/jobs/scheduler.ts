import cron from 'node-cron';
import { prisma } from '../config/database.js';
import {
  checkAndStartScheduledRooms,
  checkAndEndExpiredRooms,
  sendEndingSoonWarning,
  ensureMinimumRoomsPerRegion,
} from '../services/room.js';
import { generateBotMessage, generateTopicsFromTrending } from '../services/ai.js';
import { refreshTrendingData, cleanupExpiredTopics, cleanupExpiredTrendingItems } from '../services/trending.js';
import { broadcastToRoom } from '../websocket/index.js';

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
      console.log(`🗑️ Cleanup: ${expiredTopics} topics, ${expiredTrending} trending items removed`);
    } catch (error) {
      console.error('Error in cleanup job:', error);
    }
  });

  // Run initial trending fetch on startup (after 30 seconds to let the server stabilize)
  setTimeout(async () => {
    try {
      console.log('📰 Running initial trending data fetch...');
      const result = await generateTopicsFromTrending();
      console.log(`📰 Initial fetch: ${result.fetched} items, ${result.converted} topics created`);
    } catch (error) {
      console.error('Error in initial trending fetch:', error);
    }
  }, 30000);

  console.log('Scheduler started with the following jobs:');
  console.log('  - Room lifecycle check: every 30 seconds');
  console.log('  - Ending soon warnings: every minute');
  console.log('  - Ensure minimum rooms: every 5 minutes');
  console.log('  - Bot suggestions: every 3 minutes');
  console.log('  - Trending data refresh: every 2 hours');
  console.log('  - Topic generation from trending: every hour');
  console.log('  - Cleanup expired topics: every 6 hours');
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
async function cleanupStaleRooms(): Promise<void> {
  const aiMaxLiveTime = 45 * 60 * 1000; // 45 minutes max for AI-hosted rooms
  const userMaxLiveTime = 2 * 60 * 60 * 1000; // 2 hours max for user-created rooms
  const absoluteMaxTime = 3 * 60 * 60 * 1000; // 3 hours absolute max for any room
  
  const aiCutoffTime = new Date(Date.now() - aiMaxLiveTime);
  const userCutoffTime = new Date(Date.now() - userMaxLiveTime);
  const absoluteCutoffTime = new Date(Date.now() - absoluteMaxTime);
  
  // Find stale AI-hosted rooms (45 min)
  const staleAiRooms = await prisma.room.findMany({
    where: {
      status: 'LIVE',
      isAiHosted: true,
      startedAt: { lte: aiCutoffTime },
    },
    select: { id: true, title: true },
  });
  
  // Find user rooms without active participants (2 hours)
  const staleUserRooms = await prisma.room.findMany({
    where: {
      status: 'LIVE',
      isAiHosted: false,
      startedAt: { lte: userCutoffTime },
      participants: {
        none: {
          leftAt: null,
        },
      },
    },
    select: { id: true, title: true },
  });
  
  // Find ANY room that's been live for over 3 hours (absolute safety net)
  const veryStaleRooms = await prisma.room.findMany({
    where: {
      status: 'LIVE',
      startedAt: { lte: absoluteCutoffTime },
    },
    select: { id: true, title: true },
  });
  
  // Combine all stale rooms (using Set to avoid duplicates)
  const allStaleRoomIds = new Set([
    ...staleAiRooms.map(r => r.id),
    ...staleUserRooms.map(r => r.id),
    ...veryStaleRooms.map(r => r.id),
  ]);
  
  if (allStaleRoomIds.size > 0) {
    console.log(`Cleaning up ${allStaleRoomIds.size} stale rooms (${staleAiRooms.length} AI, ${staleUserRooms.length} empty user, ${veryStaleRooms.length} very old)`);
    
    for (const roomId of allStaleRoomIds) {
      try {
        await prisma.room.update({
          where: { id: roomId },
          data: { status: 'ENDED' },
        });
        
        await prisma.roomParticipant.updateMany({
          where: { roomId: roomId, leftAt: null },
          data: { leftAt: new Date() },
        });
        
        broadcastToRoom(roomId, {
          type: 'room:ended',
          roomId: roomId,
          payload: {},
          timestamp: new Date().toISOString(),
        });
        
        console.log(`Ended stale room: ${roomId}`);
      } catch (error) {
        console.error(`Error ending stale room ${roomId}:`, error);
      }
    }
  }
}
