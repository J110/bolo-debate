import { prisma } from '../config/database.js';
import { redis, REDIS_KEYS } from '../config/redis.js';
import { broadcastToRoom } from '../websocket/index.js';
import { generateDebateTopics, generateDebateSuggestions, generateSubtopics } from './ai.js';

const ROOM_DURATION_MS = 30 * 60 * 1000; // 30 minutes
const TARGET_LIVE_ROOMS_PER_REGION = 5;
const ROOM_INTERVAL_MINUTES = 6; // New room every 6 minutes

export async function startRoom(roomId: string): Promise<void> {
  const now = new Date();
  const endsAt = new Date(now.getTime() + ROOM_DURATION_MS);

  const room = await prisma.room.update({
    where: { id: roomId },
    data: {
      status: 'LIVE',
      startedAt: now,
      endsAt,
    },
    include: {
      host: {
        select: { id: true, username: true, displayName: true },
      },
      category: true,
      region: true,
    },
  });

  // Generate AI suggestions for the room
  if (room.type === 'DEBATE' && room.sideALabel && room.sideBLabel) {
    const [suggestions, subtopics] = await Promise.all([
      generateDebateSuggestions(room.title, room.sideALabel, room.sideBLabel),
      generateSubtopics(room.title),
    ]);

    await prisma.room.update({
      where: { id: roomId },
      data: {
        aiSuggestions: JSON.parse(JSON.stringify({ suggestions, subtopics })),
      },
    });
  }

  // Cache room state in Redis
  await redis.set(
    REDIS_KEYS.ROOM_STATE(roomId),
    JSON.stringify({
      id: room.id,
      status: room.status,
      endsAt: endsAt.toISOString(),
    }),
    'EX',
    ROOM_DURATION_MS / 1000 + 300
  );

  await redis.sadd(REDIS_KEYS.ACTIVE_ROOMS, roomId);

  broadcastToRoom(roomId, {
    type: 'room:update',
    roomId,
    payload: {
      status: 'LIVE',
      startedAt: now.toISOString(),
      endsAt: endsAt.toISOString(),
    },
    timestamp: now.toISOString(),
  });

  console.log(`Room ${roomId} started, ends at ${endsAt.toISOString()}`);
}

export async function endRoom(roomId: string): Promise<void> {
  await prisma.room.update({
    where: { id: roomId },
    data: { status: 'ENDED' },
  });

  await prisma.roomParticipant.updateMany({
    where: { roomId, leftAt: null },
    data: { leftAt: new Date() },
  });

  await redis.srem(REDIS_KEYS.ACTIVE_ROOMS, roomId);
  await redis.del(REDIS_KEYS.ROOM_STATE(roomId));
  await redis.del(REDIS_KEYS.ROOM_PARTICIPANTS(roomId));

  broadcastToRoom(roomId, {
    type: 'room:ended',
    roomId,
    payload: {},
    timestamp: new Date().toISOString(),
  });

  console.log(`Room ${roomId} ended`);
}

export async function checkAndStartScheduledRooms(): Promise<void> {
  const now = new Date();

  const roomsToStart = await prisma.room.findMany({
    where: {
      status: 'SCHEDULED',
      scheduledAt: { lte: now },
    },
  });

  for (const room of roomsToStart) {
    await startRoom(room.id);
  }

  if (roomsToStart.length > 0) {
    console.log(`Started ${roomsToStart.length} scheduled rooms`);
  }
}

export async function checkAndEndExpiredRooms(): Promise<void> {
  const now = new Date();

  const roomsToEnd = await prisma.room.findMany({
    where: {
      status: 'LIVE',
      endsAt: { lte: now },
    },
  });

  for (const room of roomsToEnd) {
    await endRoom(room.id);
  }

  if (roomsToEnd.length > 0) {
    console.log(`Ended ${roomsToEnd.length} expired rooms`);
  }
}

export async function sendEndingSoonWarning(): Promise<void> {
  const fiveMinutesFromNow = new Date(Date.now() + 5 * 60 * 1000);
  const fourMinutesFromNow = new Date(Date.now() + 4 * 60 * 1000);

  const roomsEndingSoon = await prisma.room.findMany({
    where: {
      status: 'LIVE',
      endsAt: {
        gte: fourMinutesFromNow,
        lte: fiveMinutesFromNow,
      },
    },
  });

  for (const room of roomsEndingSoon) {
    broadcastToRoom(room.id, {
      type: 'room:ending_soon',
      roomId: room.id,
      payload: { minutesRemaining: 5 },
      timestamp: new Date().toISOString(),
    });
  }
}

export async function ensureMinimumRoomsPerRegion(): Promise<void> {
  const regions = await prisma.region.findMany();
  const now = new Date();

  for (const region of regions) {
    // Count live rooms
    const liveCount = await prisma.room.count({
      where: { regionId: region.id, status: 'LIVE' },
    });

    // Count upcoming scheduled rooms (next 2 hours)
    const scheduledCount = await prisma.room.count({
      where: {
        regionId: region.id,
        status: 'SCHEDULED',
        scheduledAt: {
          gte: now,
          lte: new Date(now.getTime() + 2 * 60 * 60 * 1000),
        },
      },
    });

    // If not enough live rooms, create some immediately
    const liveRoomsNeeded = Math.max(0, TARGET_LIVE_ROOMS_PER_REGION - liveCount);
    
    // Also ensure upcoming rooms are scheduled
    const upcomingNeeded = Math.max(0, TARGET_LIVE_ROOMS_PER_REGION - scheduledCount);

    if (liveRoomsNeeded > 0 || upcomingNeeded > 0) {
      await createStaggeredRooms(region.id, liveRoomsNeeded, upcomingNeeded);
    }
  }
}

async function createStaggeredRooms(
  regionId: string, 
  liveNeeded: number, 
  scheduledNeeded: number
): Promise<void> {
  const categories = await prisma.category.findMany();
  
  if (categories.length === 0) {
    console.log('No categories found, skipping room creation');
    return;
  }

  const now = new Date();
  let roomIndex = 0;

  // Create LIVE rooms (started in the past, ending in future)
  for (let i = 0; i < liveNeeded; i++) {
    const category = categories[roomIndex % categories.length];
    roomIndex++;
    
    try {
      const topics = await generateDebateTopics(regionId, category.id, 1);
      
      if (topics.length > 0) {
        const topic = topics[0];
        
        // Stagger start times in the past (started 5, 10, 15... minutes ago)
        const minutesAgo = (i + 1) * 5;
        const startedAt = new Date(now.getTime() - minutesAgo * 60 * 1000);
        const endsAt = new Date(startedAt.getTime() + ROOM_DURATION_MS);
        
        await prisma.room.create({
          data: {
            title: topic.title,
            description: topic.description,
            regionId,
            categoryId: category.id,
            type: 'DEBATE',
            sideALabel: topic.sideALabel,
            sideBLabel: topic.sideBLabel,
            scheduledAt: startedAt,
            startedAt: startedAt,
            endsAt: endsAt,
            status: 'LIVE',
            isAiHosted: true,
          },
        });

        console.log(`Created LIVE room: ${topic.title} (ends at ${endsAt.toISOString()})`);
      }
    } catch (error) {
      console.error('Error creating live room:', error);
    }
  }

  // Create SCHEDULED rooms (staggered every 6 minutes)
  for (let i = 0; i < scheduledNeeded; i++) {
    const category = categories[roomIndex % categories.length];
    roomIndex++;
    
    try {
      const topics = await generateDebateTopics(regionId, category.id, 1);
      
      if (topics.length > 0) {
        const topic = topics[0];
        
        // Round to next 6-minute interval and add offset
        const baseMinutes = Math.ceil(now.getMinutes() / ROOM_INTERVAL_MINUTES) * ROOM_INTERVAL_MINUTES;
        const scheduledAt = new Date(now);
        scheduledAt.setMinutes(baseMinutes + (i * ROOM_INTERVAL_MINUTES), 0, 0);
        
        // If scheduled time is in the past, push to next interval
        if (scheduledAt <= now) {
          scheduledAt.setMinutes(scheduledAt.getMinutes() + ROOM_INTERVAL_MINUTES);
        }
        
        await prisma.room.create({
          data: {
            title: topic.title,
            description: topic.description,
            regionId,
            categoryId: category.id,
            type: 'DEBATE',
            sideALabel: topic.sideALabel,
            sideBLabel: topic.sideBLabel,
            scheduledAt,
            status: 'SCHEDULED',
            isAiHosted: true,
          },
        });

        console.log(`Created SCHEDULED room: ${topic.title} (at ${scheduledAt.toISOString()})`);
      }
    } catch (error) {
      console.error('Error creating scheduled room:', error);
    }
  }
}

export async function getAISuggestions(roomId: string): Promise<{
  suggestions: any;
  subtopics: string[];
} | null> {
  const room = await prisma.room.findUnique({
    where: { id: roomId },
    select: { aiSuggestions: true },
  });

  if (!room?.aiSuggestions) {
    return null;
  }

  return room.aiSuggestions as { suggestions: any; subtopics: string[] };
}
