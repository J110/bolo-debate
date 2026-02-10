import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../config/database.js';
import { ParticipantRole } from '@prisma/client';
import { authenticate, optionalAuth, getUser } from '../middleware/auth.js';
import { getLiveKitToken } from '../services/livekit.js';
import { broadcastToRoom } from '../websocket/index.js';
import { getIllustrationForTitle } from '../services/pixabay.js';
import { getRatioStats } from '../services/ratio-enforcer.js';
import { getGenericTopicStats, validateCategoryCoverage } from '../services/generic-topics.js';
import { getUsedTopicStats } from '../services/duplicate-checker.js';

// Supported languages for room discussions
const SUPPORTED_LANGUAGES = [
  'English', 'Hindi', 'Tamil', 'Telugu', 'Kannada', 'Malayalam',
  'Bengali', 'Marathi', 'Gujarati', 'Punjabi', 'Odia', 'Assamese',
  'Kashmiri', 'Konkani', 'Manipuri', 'Nepali', 'Sanskrit', 'Urdu',
] as const;

const createRoomSchema = z.object({
  title: z.string().min(5).max(200),
  description: z.string().max(1000).optional(),
  regionId: z.string().uuid(),
  categoryId: z.string().uuid(),
  type: z.enum(['DEBATE', 'DISCUSSION']),
  sideALabel: z.string().max(50).optional(),
  sideBLabel: z.string().max(50).optional(),
  language: z.enum(SUPPORTED_LANGUAGES).optional().default('English'),
  scheduledAt: z.string().datetime(),
});

const joinRoomSchema = z.object({
  side: z.enum(['A', 'B', 'NEUTRAL']).optional(),
  pledgeAccepted: z.boolean(),
});

export async function roomRoutes(app: FastifyInstance) {
  // List rooms with filters
  app.get('/', { preHandler: optionalAuth }, async (request, reply) => {
    const {
      regionId,
      categoryId,
      status,
      type,
      page = '1',
      limit = '20',
    } = request.query as {
      regionId?: string;
      categoryId?: string;
      status?: string;
      type?: string;
      page?: string;
      limit?: string;
    };

    const pageNum = parseInt(page, 10);
    const limitNum = Math.min(parseInt(limit, 10), 50);

    const where: any = {};
    if (regionId) where.regionId = regionId;
    if (categoryId) where.categoryId = categoryId;
    if (status) where.status = status;
    if (type) where.type = type;

    const [rooms, total] = await Promise.all([
      prisma.room.findMany({
        where,
        include: {
          host: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
          region: { select: { id: true, name: true, state: true } },
          category: true,
          _count: { select: { participants: true } },
        },
        orderBy: [
          { status: 'asc' }, // LIVE first, then SCHEDULED
          { scheduledAt: 'asc' },
        ],
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
      }),
      prisma.room.count({ where }),
    ]);

    return reply.send({
      success: true,
      data: {
        items: rooms.map(room => ({
          ...room,
          participantCount: room._count.participants,
        })),
        total,
        page: pageNum,
        pageSize: limitNum,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  });

  // Get live rooms for home page
  app.get('/live', async (request, reply) => {
    const { regionId, categoryId, limit = '10' } = request.query as {
      regionId?: string;
      categoryId?: string;
      limit?: string;
    };

    const limitNum = Math.min(parseInt(limit, 10), 20);

    const rooms = await prisma.room.findMany({
      where: {
        status: 'LIVE',
        ...(regionId ? { regionId } : {}),
        ...(categoryId ? { categoryId } : {}),
      },
      include: {
        host: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        region: { select: { id: true, name: true, state: true } },
        category: true,
        _count: { select: { participants: true } },
        participants: {
          select: { side: true },
        },
      },
      orderBy: { startedAt: 'desc' },
      take: limitNum,
    });

    return reply.send({
      success: true,
      data: rooms.map(room => ({
        ...room,
        participantCount: room._count.participants,
        sideACount: room.participants.filter(p => p.side === 'A').length,
        sideBCount: room.participants.filter(p => p.side === 'B').length,
        participants: undefined,
      })),
    });
  });

  // Get scheduled rooms
  app.get('/scheduled', async (request, reply) => {
    const { regionId, categoryId, limit = '10' } = request.query as {
      regionId?: string;
      categoryId?: string;
      limit?: string;
    };

    const limitNum = Math.min(parseInt(limit, 10), 20);

    const rooms = await prisma.room.findMany({
      where: {
        status: 'SCHEDULED',
        scheduledAt: { gte: new Date() },
        ...(regionId ? { regionId } : {}),
        ...(categoryId ? { categoryId } : {}),
      },
      include: {
        host: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        region: { select: { id: true, name: true, state: true } },
        category: true,
        _count: { select: { participants: true } },
      },
      orderBy: { scheduledAt: 'asc' },
      take: limitNum,
    });

    return reply.send({
      success: true,
      data: rooms.map(room => ({
        ...room,
        participantCount: room._count.participants,
      })),
    });
  });

  // Get room details
  app.get('/:id', { preHandler: optionalAuth }, async (request, reply) => {
    const { id } = request.params as { id: string };

    const room = await prisma.room.findUnique({
      where: { id },
      include: {
        host: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        region: true,
        category: true,
        participants: {
          where: { leftAt: null },
          include: {
            user: {
              select: { id: true, username: true, displayName: true, avatarUrl: true },
            },
          },
          orderBy: { joinedAt: 'asc' },
        },
      },
    });

    if (!room) {
      return reply.status(404).send({
        success: false,
        error: 'Room not found',
      });
    }

    return reply.send({
      success: true,
      data: {
        ...room,
        participantCount: room.participants.length,
        sideACount: room.participants.filter(p => p.side === 'A').length,
        sideBCount: room.participants.filter(p => p.side === 'B').length,
      },
    });
  });

  // Create room
  app.post('/', { preHandler: authenticate }, async (request, reply) => {
    try {
      const body = createRoomSchema.parse(request.body);
      const userId = getUser(request).userId;

      // Validate scheduled time is at least 30 minutes in the future
      const scheduledAt = new Date(body.scheduledAt);
      const minScheduleTime = new Date(Date.now() + 29 * 60 * 1000); // 29 minutes buffer

      if (scheduledAt < minScheduleTime) {
        return reply.status(400).send({
          success: false,
          error: 'Room must be scheduled at least 30 minutes in advance',
        });
      }

      // For debates, both side labels are required
      if (body.type === 'DEBATE' && (!body.sideALabel || !body.sideBLabel)) {
        return reply.status(400).send({
          success: false,
          error: 'Debate rooms require both side labels',
        });
      }

      // Fetch illustration from title (handles both English and Hindi)
      const illustrationUrl = await getIllustrationForTitle(body.title);

      const room = await prisma.room.create({
        data: {
          ...body,
          hostId: userId,
          scheduledAt,
          illustrationUrl,
          isAiHosted: false,
        },
        include: {
          host: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
          region: true,
          category: true,
        },
      });

      return reply.status(201).send({
        success: true,
        data: room,
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return reply.status(400).send({
          success: false,
          error: 'Validation error',
          details: error.errors,
        });
      }
      throw error;
    }
  });

  // Join room
  app.post('/:id/join', { preHandler: authenticate }, async (request, reply) => {
    try {
      const { id } = request.params as { id: string };
      const body = joinRoomSchema.parse(request.body);
      const userId = getUser(request).userId;

      if (!body.pledgeAccepted) {
        return reply.status(400).send({
          success: false,
          error: 'You must accept the pledge to join the room',
        });
      }

      const room = await prisma.room.findUnique({
        where: { id },
      });

      if (!room) {
        return reply.status(404).send({
          success: false,
          error: 'Room not found',
        });
      }

      if (room.status === 'ENDED') {
        return reply.status(400).send({
          success: false,
          error: 'Room has ended',
        });
      }

      // Check if already in room
      const existingParticipant = await prisma.roomParticipant.findUnique({
        where: {
          roomId_userId: { roomId: id, userId },
        },
      });

      if (existingParticipant && !existingParticipant.leftAt) {
        return reply.status(400).send({
          success: false,
          error: 'Already in room',
        });
      }

      // Determine side
      let side = body.side || 'NEUTRAL';
      if (room.type === 'DISCUSSION') {
        side = 'NEUTRAL';
      }

      // Determine role - first few people on each side get SPEAKER role
      const isHost = room.hostId === userId;
      let role: ParticipantRole = isHost ? ParticipantRole.HOST : ParticipantRole.LISTENER;
      
      // Auto-promote to SPEAKER if one of the first 3 on your side (not neutral)
      if (!isHost && side !== 'NEUTRAL') {
        const sideParticipants = await prisma.roomParticipant.count({
          where: { roomId: id, side, leftAt: null },
        });
        if (sideParticipants < 3) {
          role = ParticipantRole.SPEAKER;
        }
      }
      
      // Speakers start unmuted, listeners start muted
      const startMuted = role === ParticipantRole.LISTENER;

      // Create or update participant
      const participant = existingParticipant
        ? await prisma.roomParticipant.update({
            where: { id: existingParticipant.id },
            data: { side, role, leftAt: null, handRaised: false, isMuted: startMuted },
            include: {
              user: {
                select: { id: true, username: true, displayName: true, avatarUrl: true },
              },
            },
          })
        : await prisma.roomParticipant.create({
            data: { roomId: id, userId, side, role, isMuted: startMuted },
            include: {
              user: {
                select: { id: true, username: true, displayName: true, avatarUrl: true },
              },
            },
          });

      // Broadcast participant joined
      broadcastToRoom(id, {
        type: 'participant:joined',
        roomId: id,
        payload: participant,
        timestamp: new Date().toISOString(),
      });

      return reply.send({
        success: true,
        data: participant,
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return reply.status(400).send({
          success: false,
          error: 'Validation error',
        });
      }
      throw error;
    }
  });

  // Leave room
  app.post('/:id/leave', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = getUser(request).userId;

    const participant = await prisma.roomParticipant.findUnique({
      where: {
        roomId_userId: { roomId: id, userId },
      },
    });

    if (!participant || participant.leftAt) {
      return reply.status(400).send({
        success: false,
        error: 'Not in room',
      });
    }

    await prisma.roomParticipant.update({
      where: { id: participant.id },
      data: { leftAt: new Date() },
    });

    // Broadcast participant left
    broadcastToRoom(id, {
      type: 'participant:left',
      roomId: id,
      payload: { oderId: userId },
      timestamp: new Date().toISOString(),
    });

    return reply.send({
      success: true,
      message: 'Left room',
    });
  });

  // Get LiveKit token for room
  app.get('/:id/token', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = getUser(request).userId;

    const participant = await prisma.roomParticipant.findUnique({
      where: {
        roomId_userId: { roomId: id, userId },
      },
      include: {
        user: true,
        room: true,
      },
    });

    if (!participant || participant.leftAt) {
      return reply.status(403).send({
        success: false,
        error: 'Must join room first',
      });
    }

    if (participant.room.status !== 'LIVE') {
      return reply.status(400).send({
        success: false,
        error: 'Room is not live',
      });
    }

    const token = await getLiveKitToken(id, userId, participant.user.displayName);

    return reply.send({
      success: true,
      data: { token },
    });
  });

  // Raise/lower hand
  app.post('/:id/hand', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { raised } = request.body as { raised: boolean };
    const userId = getUser(request).userId;

    const participant = await prisma.roomParticipant.findUnique({
      where: {
        roomId_userId: { roomId: id, userId },
      },
    });

    if (!participant || participant.leftAt) {
      return reply.status(400).send({
        success: false,
        error: 'Not in room',
      });
    }

    await prisma.roomParticipant.update({
      where: { id: participant.id },
      data: { handRaised: raised },
    });

    broadcastToRoom(id, {
      type: raised ? 'hand:raised' : 'hand:lowered',
      roomId: id,
      payload: { oderId: userId },
      timestamp: new Date().toISOString(),
    });

    return reply.send({
      success: true,
      data: { handRaised: raised },
    });
  });

  // Toggle mute
  app.post('/:id/mute', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { muted } = request.body as { muted: boolean };
    const userId = getUser(request).userId;

    const participant = await prisma.roomParticipant.findUnique({
      where: {
        roomId_userId: { roomId: id, userId },
      },
    });

    if (!participant || participant.leftAt) {
      return reply.status(400).send({
        success: false,
        error: 'Not in room',
      });
    }

    // Only hosts, speakers, or hand-raised listeners can unmute
    if (!muted && participant.role === 'LISTENER' && !participant.handRaised) {
      return reply.status(403).send({
        success: false,
        error: 'Raise your hand to speak',
      });
    }

    await prisma.roomParticipant.update({
      where: { id: participant.id },
      data: { isMuted: muted },
    });

    return reply.send({
      success: true,
      data: { isMuted: muted },
    });
  });

  // Extend room time (host only)
  app.post('/:id/extend', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = getUser(request).userId;

    const room = await prisma.room.findUnique({
      where: { id },
    });

    if (!room) {
      return reply.status(404).send({
        success: false,
        error: 'Room not found',
      });
    }

    if (room.hostId !== userId) {
      return reply.status(403).send({
        success: false,
        error: 'Only the host can extend the room',
      });
    }

    if (room.extensionsUsed >= 3) {
      return reply.status(400).send({
        success: false,
        error: 'Maximum 3 extensions allowed (15 minutes total)',
      });
    }

    if (!room.endsAt) {
      return reply.status(400).send({
        success: false,
        error: 'Room has not started',
      });
    }

    const newEndsAt = new Date(room.endsAt.getTime() + 5 * 60 * 1000);

    await prisma.room.update({
      where: { id },
      data: {
        endsAt: newEndsAt,
        extensionsUsed: room.extensionsUsed + 1,
      },
    });

    broadcastToRoom(id, {
      type: 'room:update',
      roomId: id,
      payload: {
        endsAt: newEndsAt.toISOString(),
        extensionsUsed: room.extensionsUsed + 1,
      },
      timestamp: new Date().toISOString(),
    });

    return reply.send({
      success: true,
      data: {
        endsAt: newEndsAt,
        extensionsUsed: room.extensionsUsed + 1,
      },
    });
  });

  // Claim host (for AI-hosted rooms)
  app.post('/:id/claim-host', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const userId = getUser(request).userId;

    const room = await prisma.room.findUnique({
      where: { id },
    });

    if (!room) {
      return reply.status(404).send({
        success: false,
        error: 'Room not found',
      });
    }

    if (!room.isAiHosted) {
      return reply.status(400).send({
        success: false,
        error: 'Room is not AI-hosted',
      });
    }

    if (room.hostId) {
      return reply.status(400).send({
        success: false,
        error: 'Room already has a host',
      });
    }

    // Check if user is a participant
    const participant = await prisma.roomParticipant.findUnique({
      where: {
        roomId_userId: { roomId: id, userId },
      },
    });

    if (!participant || participant.leftAt) {
      return reply.status(400).send({
        success: false,
        error: 'Must join room first',
      });
    }

    // Update room and participant
    await prisma.$transaction([
      prisma.room.update({
        where: { id },
        data: { hostId: userId, isAiHosted: false },
      }),
      prisma.roomParticipant.update({
        where: { id: participant.id },
        data: { role: 'HOST' },
      }),
    ]);

    const updatedRoom = await prisma.room.findUnique({
      where: { id },
      include: {
        host: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    broadcastToRoom(id, {
      type: 'room:update',
      roomId: id,
      payload: { host: updatedRoom!.host, isAiHosted: false },
      timestamp: new Date().toISOString(),
    });

    return reply.send({
      success: true,
      data: updatedRoom,
    });
  });

  // Kick participant (host only)
  app.delete('/:id/kick/:userId', { preHandler: authenticate }, async (request, reply) => {
    const { id, userId: targetUserId } = request.params as { id: string; userId: string };
    const userId = getUser(request).userId;

    const room = await prisma.room.findUnique({
      where: { id },
    });

    if (!room) {
      return reply.status(404).send({
        success: false,
        error: 'Room not found',
      });
    }

    if (room.hostId !== userId) {
      return reply.status(403).send({
        success: false,
        error: 'Only the host can kick participants',
      });
    }

    if (targetUserId === userId) {
      return reply.status(400).send({
        success: false,
        error: 'Cannot kick yourself',
      });
    }

    await prisma.roomParticipant.updateMany({
      where: { roomId: id, userId: targetUserId, leftAt: null },
      data: { leftAt: new Date() },
    });

    broadcastToRoom(id, {
      type: 'participant:left',
      roomId: id,
      payload: { oderId: targetUserId, kicked: true },
      timestamp: new Date().toISOString(),
    });

    return reply.send({
      success: true,
      message: 'Participant kicked',
    });
  });

  // Send chat message
  app.post('/:id/messages', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { content } = request.body as { content: string };
    const userId = getUser(request).userId;

    if (!content || content.trim().length === 0) {
      return reply.status(400).send({
        success: false,
        error: 'Message cannot be empty',
      });
    }

    if (content.length > 500) {
      return reply.status(400).send({
        success: false,
        error: 'Message too long',
      });
    }

    const participant = await prisma.roomParticipant.findUnique({
      where: {
        roomId_userId: { roomId: id, userId },
      },
    });

    if (!participant || participant.leftAt) {
      return reply.status(403).send({
        success: false,
        error: 'Must be in room to send messages',
      });
    }

    const message = await prisma.message.create({
      data: { roomId: id, userId, content: content.trim() },
      include: {
        user: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    broadcastToRoom(id, {
      type: 'message:new',
      roomId: id,
      payload: message,
      timestamp: new Date().toISOString(),
    });

    return reply.status(201).send({
      success: true,
      data: message,
    });
  });

  // Get chat history
  app.get('/:id/messages', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { limit = '50', before } = request.query as { limit?: string; before?: string };

    const limitNum = Math.min(parseInt(limit, 10), 100);

    const messages = await prisma.message.findMany({
      where: {
        roomId: id,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      include: {
        user: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limitNum,
    });

    return reply.send({
      success: true,
      data: messages.reverse(),
    });
  });

  // Send reaction
  app.post('/:id/reactions', { preHandler: authenticate }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { emoji } = request.body as { emoji: string };
    const userId = getUser(request).userId;

    const allowedEmojis = ['👏', '🔥', '💯', '🤔', '👍', '👎', '❤️', '😂'];
    if (!allowedEmojis.includes(emoji)) {
      return reply.status(400).send({
        success: false,
        error: 'Invalid emoji',
      });
    }

    const participant = await prisma.roomParticipant.findUnique({
      where: {
        roomId_userId: { roomId: id, userId },
      },
    });

    if (!participant || participant.leftAt) {
      return reply.status(403).send({
        success: false,
        error: 'Must be in room to react',
      });
    }

    const reaction = await prisma.reaction.create({
      data: { roomId: id, userId, emoji },
      include: {
        user: {
          select: { id: true, username: true, displayName: true },
        },
      },
    });

    broadcastToRoom(id, {
      type: 'reaction:new',
      roomId: id,
      payload: reaction,
      timestamp: new Date().toISOString(),
    });

    return reply.status(201).send({
      success: true,
      data: reaction,
    });
  });

  // Get topic system statistics
  app.get('/stats/topics', async (request, reply) => {
    try {
      const [ratioStats, genericStats, usedStats] = await Promise.all([
        getRatioStats(),
        getGenericTopicStats(),
        getUsedTopicStats(),
      ]);

      // Get rooms by language
      const [hindiRooms, englishRooms] = await Promise.all([
        prisma.room.count({ where: { language: 'Hindi', status: { in: ['LIVE', 'SCHEDULED'] } } }),
        prisma.room.count({ where: { language: 'English', status: { in: ['LIVE', 'SCHEDULED'] } } }),
      ]);

      // Get category coverage
      const categories = await prisma.category.findMany({
        select: { id: true, name: true },
      });

      const categoryCoverage = await Promise.all(
        categories.map(async (cat) => {
          const [live, scheduled] = await Promise.all([
            prisma.room.count({ where: { categoryId: cat.id, status: 'LIVE' } }),
            prisma.room.count({ where: { categoryId: cat.id, status: 'SCHEDULED' } }),
          ]);
          return {
            category: cat.name,
            live,
            scheduled,
            covered: live >= 1 && scheduled >= 1,
          };
        })
      );

      return reply.send({
        success: true,
        data: {
          ratios: {
            localToGeneric: {
              local: ratioStats.distribution.byTopicType.trending,
              generic: ratioStats.distribution.byTopicType.generic + ratioStats.distribution.byTopicType.international,
              percentage: (ratioStats.localRatio * 100).toFixed(1) + '%',
              target: '50%',
              balanced: Math.abs(ratioStats.localRatio - 0.5) <= 0.1,
            },
            hindiToEnglish: {
              hindi: hindiRooms,
              english: englishRooms,
              percentage: ratioStats.distribution.totalRooms > 0 
                ? ((hindiRooms / ratioStats.distribution.totalRooms) * 100).toFixed(1) + '%'
                : '50%',
              target: '50%',
              balanced: Math.abs(ratioStats.hindiRatio - 0.5) <= 0.1,
            },
          },
          topicPool: {
            generic: {
              totalPredefined: genericStats.totalPredefined,
              inQueue: genericStats.inQueue,
              usedInLast3Months: genericStats.usedInLast3Months,
            },
            usedTopics: {
              total: usedStats.total,
              byType: usedStats.byType,
              byLanguage: usedStats.byLanguage,
            },
          },
          categoryCoverage,
          allCategoriesCovered: categoryCoverage.every(c => c.covered),
          totalActiveRooms: ratioStats.distribution.totalRooms,
        },
      });
    } catch (error) {
      console.error('Error fetching topic stats:', error);
      return reply.status(500).send({
        success: false,
        error: 'Failed to fetch topic statistics',
      });
    }
  });

  // Validate category coverage for generic topics
  app.get('/stats/category-health', async (request, reply) => {
    try {
      const coverage = await validateCategoryCoverage();
      
      return reply.send({
        success: true,
        data: {
          isComplete: coverage.isComplete,
          minimumTopicsRequired: 10,
          categories: coverage.categories,
          actionRequired: coverage.categories
            .filter(c => !c.hasMinimum)
            .map(c => ({ category: c.name, recommendation: c.recommendation })),
        },
      });
    } catch (error) {
      console.error('Error validating category coverage:', error);
      return reply.status(500).send({
        success: false,
        error: 'Failed to validate category coverage',
      });
    }
  });

  // Get rooms grouped by category
  app.get('/by-category', async (request, reply) => {
    const { status } = request.query as { status?: string };

    const categories = await prisma.category.findMany({
      orderBy: { name: 'asc' },
    });

    const roomsByCategory = await Promise.all(
      categories.map(async (category) => {
        const rooms = await prisma.room.findMany({
          where: status 
            ? { categoryId: category.id, status: status as 'LIVE' | 'SCHEDULED' | 'ENDED' }
            : { categoryId: category.id, status: { in: ['LIVE', 'SCHEDULED'] } },
          include: {
            region: { select: { id: true, name: true } },
            _count: { select: { participants: true } },
          },
          orderBy: [
            { status: 'asc' },
            { scheduledAt: 'asc' },
          ],
          take: 10,
        });

        return {
          category: {
            id: category.id,
            name: category.name,
            icon: category.icon,
          },
          liveCount: rooms.filter(r => r.status === 'LIVE').length,
          scheduledCount: rooms.filter(r => r.status === 'SCHEDULED').length,
          rooms: rooms.map(room => ({
            id: room.id,
            title: room.title,
            status: room.status,
            language: room.language,
            regionId: room.regionId,
            regionName: room.region?.name,
            participantCount: room._count.participants,
            scheduledAt: room.scheduledAt,
            startedAt: room.startedAt,
            endsAt: room.endsAt,
          })),
        };
      })
    );

    return reply.send({
      success: true,
      data: roomsByCategory,
    });
  });
}
