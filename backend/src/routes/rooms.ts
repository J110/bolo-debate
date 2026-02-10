import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../config/database.js';
import { ParticipantRole } from '@prisma/client';
import { authenticate, optionalAuth, getUser } from '../middleware/auth.js';
import { getLiveKitToken } from '../services/livekit.js';
import { broadcastToRoom } from '../websocket/index.js';
import { getIllustrationForTitle } from '../services/pixabay.js';

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
}
