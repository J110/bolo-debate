import { prisma } from '../config/database.js';
import { redis, REDIS_KEYS } from '../config/redis.js';
import { broadcastToRoom } from '../websocket/index.js';
import { generateDebateTopics, generateDebateSuggestions, generateSubtopics } from './ai.js';

const ROOM_DURATION_MS = 30 * 60 * 1000; // 30 minutes
const TARGET_LIVE_ROOMS_PER_REGION = 5;

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
    ROOM_DURATION_MS / 1000 + 300 // TTL slightly longer than room duration
  );

  // Add to active rooms set
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

  // Mark all participants as left
  await prisma.roomParticipant.updateMany({
    where: { roomId, leftAt: null },
    data: { leftAt: new Date() },
  });

  // Remove from Redis
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

  // Find rooms that should start
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

  // Find rooms that should end
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

  // Find rooms ending in approximately 5 minutes
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
  // Get all regions
  const regions = await prisma.region.findMany();

  for (const region of regions) {
    // Count live + upcoming scheduled rooms for this region
    const [liveCount, scheduledCount] = await Promise.all([
      prisma.room.count({
        where: { regionId: region.id, status: 'LIVE' },
      }),
      prisma.room.count({
        where: {
          regionId: region.id,
          status: 'SCHEDULED',
          scheduledAt: {
            gte: new Date(),
            lte: new Date(Date.now() + 60 * 60 * 1000), // Next hour
          },
        },
      }),
    ]);

    const totalRooms = liveCount + scheduledCount;
    const roomsNeeded = TARGET_LIVE_ROOMS_PER_REGION - totalRooms;

    if (roomsNeeded > 0) {
      await createAIHostedRooms(region.id, roomsNeeded);
    }
  }
}

async function createAIHostedRooms(regionId: string, count: number): Promise<void> {
  // Get random categories
  const categories = await prisma.category.findMany();
  
  if (categories.length === 0) {
    console.log('No categories found, skipping AI room creation');
    return;
  }

  for (let i = 0; i < count; i++) {
    const category = categories[Math.floor(Math.random() * categories.length)];
    
    try {
      const topics = await generateDebateTopics(regionId, category.id, 1);
      
      if (topics.length > 0) {
        const topic = topics[0];
        
        // Schedule 30 minutes from now
        const scheduledAt = new Date(Date.now() + 30 * 60 * 1000);
        
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
            isAiHosted: true,
          },
        });

        console.log(`Created AI-hosted room: ${topic.title}`);
      }
    } catch (error) {
      console.error('Error creating AI-hosted room:', error);
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
