import cron from 'node-cron';
import { prisma } from '../config/database.js';
import {
  checkAndStartScheduledRooms,
  checkAndEndExpiredRooms,
  sendEndingSoonWarning,
  ensureMinimumRoomsPerRegion,
} from '../services/room.js';
import { generateBotMessage } from '../services/ai.js';
import { broadcastToRoom } from '../websocket/index.js';

export function startScheduler(): void {
  console.log('✅ Starting scheduler...');

  // Check for rooms to start/end every 30 seconds
  cron.schedule('*/30 * * * * *', async () => {
    try {
      await checkAndStartScheduledRooms();
      await checkAndEndExpiredRooms();
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

  console.log('Scheduler started with the following jobs:');
  console.log('  - Room lifecycle check: every 30 seconds');
  console.log('  - Ending soon warnings: every minute');
  console.log('  - Ensure minimum rooms: every 5 minutes');
  console.log('  - Bot suggestions: every 3 minutes');
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
