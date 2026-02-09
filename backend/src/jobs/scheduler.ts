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

// Clean up stale rooms (live for over 45 minutes without extension by human host)
async function cleanupStaleRooms(): Promise<void> {
  const maxLiveTime = 45 * 60 * 1000; // 45 minutes max for AI-hosted rooms
  const cutoffTime = new Date(Date.now() - maxLiveTime);
  
  // Find rooms that have been live too long
  const staleRooms = await prisma.room.findMany({
    where: {
      status: 'LIVE',
      isAiHosted: true,
      startedAt: { lte: cutoffTime },
    },
    select: { id: true },
  });
  
  if (staleRooms.length > 0) {
    console.log(`Cleaning up ${staleRooms.length} stale AI-hosted rooms`);
    
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
        
        console.log(`Ended stale room: ${room.id}`);
      } catch (error) {
        console.error(`Error ending stale room ${room.id}:`, error);
      }
    }
  }
}
