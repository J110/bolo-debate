import { prisma } from '../config/database.js';
import { redis, REDIS_KEYS } from '../config/redis.js';
import { broadcastToRoom } from '../websocket/index.js';
import { generateDebateTopics, generateDebateSuggestions, generateSubtopics, translateTopicToHindi } from './ai.js';
import { getIllustrationForTitle } from './pixabay.js';

const ROOM_DURATION_MS = 30 * 60 * 1000; // 30 minutes
const MIN_LIVE_ROOMS_PER_REGION = 1; // At least 1 live room per region
const MIN_SCHEDULED_ROOMS_PER_REGION = 1; // At least 1 upcoming room per region
const ROOM_INTERVAL_MINUTES = 6; // New room every 6 minutes

// Randomly select Hindi or English for room language
// Topics will be localized but discussion language is Hindi or English
function getRandomLanguage(): string {
  return Math.random() < 0.5 ? 'Hindi' : 'English';
}

export async function startRoom(roomId: string): Promise<void> {
  const now = new Date();
  
  // Get the room first to check its scheduledAt
  const existingRoom = await prisma.room.findUnique({
    where: { id: roomId },
  });
  
  if (!existingRoom) return;
  
  // Use the original scheduledAt as startedAt if it's in the past,
  // otherwise use now. This preserves staggered start times.
  const startedAt = existingRoom.scheduledAt <= now 
    ? existingRoom.scheduledAt 
    : now;
  const endsAt = new Date(startedAt.getTime() + ROOM_DURATION_MS);

  const room = await prisma.room.update({
    where: { id: roomId },
    data: {
      status: 'LIVE',
      startedAt,
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
  // Get ALL regions - ensure every region has rooms
  const regions = await prisma.region.findMany();
  const now = new Date();

  console.log(`📍 Ensuring rooms for ${regions.length} regions: ${regions.map(r => r.name).join(', ')}`);

  for (let regionIndex = 0; regionIndex < regions.length; regionIndex++) {
    const region = regions[regionIndex];
    
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

    // Ensure at least MIN_LIVE_ROOMS_PER_REGION live rooms
    const liveRoomsNeeded = Math.max(0, MIN_LIVE_ROOMS_PER_REGION - liveCount);
    
    // Ensure at least MIN_SCHEDULED_ROOMS_PER_REGION upcoming rooms
    const upcomingNeeded = Math.max(0, MIN_SCHEDULED_ROOMS_PER_REGION - scheduledCount);

    if (liveRoomsNeeded > 0 || upcomingNeeded > 0) {
      console.log(`  📍 ${region.name}: creating ${liveRoomsNeeded} live, ${upcomingNeeded} scheduled`);
      // Pass region index to stagger rooms across regions
      await createStaggeredRooms(region.id, liveRoomsNeeded, upcomingNeeded, regionIndex);
    } else {
      console.log(`  ✓ ${region.name}: has ${liveCount} live, ${scheduledCount} scheduled`);
    }
  }
}

async function createStaggeredRooms(
  regionId: string, 
  liveNeeded: number, 
  scheduledNeeded: number,
  regionIndex: number = 0
): Promise<void> {
  const categories = await prisma.category.findMany();
  const region = await prisma.region.findUnique({ where: { id: regionId } });
  
  if (categories.length === 0 || !region) {
    console.log('No categories or region found, skipping room creation');
    return;
  }

  const now = new Date();
  
  // Offset based on region index to stagger rooms across regions
  // Each region gets a 3-minute offset (0, 3, 6, 9, 12, 15, 18 minutes)
  const regionOffset = regionIndex * 3;

  // Each region starts with a different category for maximum diversity
  // This ensures different regions don't create rooms in the same category simultaneously
  let categoryIndex = regionIndex % categories.length;

  // Create LIVE rooms (started in the past at staggered intervals)
  for (let i = 0; i < liveNeeded; i++) {
    const category = categories[categoryIndex % categories.length];
    categoryIndex++; // Move to next category for next room
    
    // Each room gets random language independently
    const language = getRandomLanguage();
    
    try {
      const topics = await generateDebateTopics(regionId, category.id, 1);
      
      if (topics.length > 0) {
        let topic = topics[0];
        
        // Fetch illustration from English title BEFORE translation
        const illustrationUrl = await getIllustrationForTitle(topic.title);
        
        // Translate to Hindi if room language is Hindi
        if (language === 'Hindi') {
          const translated = await translateTopicToHindi(topic);
          topic = { ...topic, ...translated };
        }
        
        // Stagger start times: base offset per region + room index offset
        // Region 0: 3 min ago, Region 1: 6 min ago, Region 2: 9 min ago, etc.
        const minutesAgo = regionOffset + 3 + (i * ROOM_INTERVAL_MINUTES);
        const startedAt = new Date(now.getTime() - minutesAgo * 60 * 1000);
        const endsAt = new Date(startedAt.getTime() + ROOM_DURATION_MS);
        
        // Only create if room would still be live (not ended)
        if (endsAt > now) {
          await prisma.room.create({
            data: {
              title: topic.title,
              description: topic.description,
              regionId,
              categoryId: category.id,
              type: 'DEBATE',
              sideALabel: topic.sideALabel,
              sideBLabel: topic.sideBLabel,
              language,
              illustrationUrl,
              scheduledAt: startedAt,
              startedAt: startedAt,
              endsAt: endsAt,
              status: 'LIVE',
              isAiHosted: true,
            },
          });

          console.log(`Created LIVE room [${region.name}] (${language}): ${topic.title} (started ${minutesAgo}m ago)`);
        }
      }
    } catch (error) {
      console.error('Error creating live room:', error);
    }
  }

  // Create SCHEDULED rooms (staggered into the future)
  for (let i = 0; i < scheduledNeeded; i++) {
    const category = categories[categoryIndex % categories.length];
    categoryIndex++; // Move to next category for next room
    
    // Each room gets random language independently
    const language = getRandomLanguage();
    
    try {
      const topics = await generateDebateTopics(regionId, category.id, 1);
      
      if (topics.length > 0) {
        let topic = topics[0];
        
        // Fetch illustration from English title BEFORE translation
        const illustrationUrl = await getIllustrationForTitle(topic.title);
        
        // Translate to Hindi if room language is Hindi
        if (language === 'Hindi') {
          const translated = await translateTopicToHindi(topic);
          topic = { ...topic, ...translated };
        }
        
        // Stagger scheduled times: base offset per region + room index offset
        // Region 0: in 3 min, Region 1: in 6 min, Region 2: in 9 min, etc.
        const minutesFromNow = regionOffset + 3 + (i * ROOM_INTERVAL_MINUTES);
        const scheduledAt = new Date(now.getTime() + minutesFromNow * 60 * 1000);
        // Round to nearest minute for cleaner times
        scheduledAt.setSeconds(0, 0);
        
        await prisma.room.create({
          data: {
            title: topic.title,
            description: topic.description,
            regionId,
            categoryId: category.id,
            type: 'DEBATE',
            sideALabel: topic.sideALabel,
            sideBLabel: topic.sideBLabel,
            language,
            illustrationUrl,
            scheduledAt,
            status: 'SCHEDULED',
            isAiHosted: true,
          },
        });

        console.log(`Created SCHEDULED room [${region.name}] (${language}): ${topic.title} (in ${minutesFromNow}m)`);
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
