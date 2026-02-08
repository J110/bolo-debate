import { FastifyInstance } from 'fastify';
import { prisma } from '../config/database.js';
import { authenticate, getUser } from '../middleware/auth.js';

export async function friendRoutes(app: FastifyInstance) {
  // Get friends list
  app.get('/', { preHandler: authenticate }, async (request, reply) => {
    const userId = getUser(request).userId;

    const friendships = await prisma.friendship.findMany({
      where: {
        OR: [
          { userId, status: 'ACCEPTED' },
          { friendId: userId, status: 'ACCEPTED' },
        ],
      },
      include: {
        user: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
        friend: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    // Return the other user in each friendship
    const friends = friendships.map(f => 
      f.userId === userId ? f.friend : f.user
    );

    return reply.send({
      success: true,
      data: friends,
    });
  });

  // Get pending friend requests
  app.get('/requests', { preHandler: authenticate }, async (request, reply) => {
    const userId = getUser(request).userId;

    const [incoming, outgoing] = await Promise.all([
      prisma.friendship.findMany({
        where: { friendId: userId, status: 'PENDING' },
        include: {
          user: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
      }),
      prisma.friendship.findMany({
        where: { userId, status: 'PENDING' },
        include: {
          friend: {
            select: { id: true, username: true, displayName: true, avatarUrl: true },
          },
        },
      }),
    ]);

    return reply.send({
      success: true,
      data: {
        incoming: incoming.map(f => ({ ...f.user, requestId: f.id })),
        outgoing: outgoing.map(f => ({ ...f.friend, requestId: f.id })),
      },
    });
  });

  // Send friend request
  app.post('/request', { preHandler: authenticate }, async (request, reply) => {
    const userId = getUser(request).userId;
    const { username } = request.body as { username: string };

    if (!username) {
      return reply.status(400).send({
        success: false,
        error: 'Username required',
      });
    }

    // Find the target user
    const targetUser = await prisma.user.findUnique({
      where: { username: username.toLowerCase() },
    });

    if (!targetUser) {
      return reply.status(404).send({
        success: false,
        error: 'User not found',
      });
    }

    if (targetUser.id === userId) {
      return reply.status(400).send({
        success: false,
        error: 'Cannot friend yourself',
      });
    }

    // Check if friendship already exists
    const existing = await prisma.friendship.findFirst({
      where: {
        OR: [
          { userId, friendId: targetUser.id },
          { userId: targetUser.id, friendId: userId },
        ],
      },
    });

    if (existing) {
      if (existing.status === 'ACCEPTED') {
        return reply.status(400).send({
          success: false,
          error: 'Already friends',
        });
      }
      return reply.status(400).send({
        success: false,
        error: 'Friend request already exists',
      });
    }

    const friendship = await prisma.friendship.create({
      data: {
        userId,
        friendId: targetUser.id,
        status: 'PENDING',
      },
      include: {
        friend: {
          select: { id: true, username: true, displayName: true, avatarUrl: true },
        },
      },
    });

    return reply.status(201).send({
      success: true,
      data: friendship,
    });
  });

  // Accept friend request
  app.post('/accept/:id', { preHandler: authenticate }, async (request, reply) => {
    const userId = getUser(request).userId;
    const { id } = request.params as { id: string };

    const friendship = await prisma.friendship.findUnique({
      where: { id },
    });

    if (!friendship) {
      return reply.status(404).send({
        success: false,
        error: 'Friend request not found',
      });
    }

    if (friendship.friendId !== userId) {
      return reply.status(403).send({
        success: false,
        error: 'Not your friend request',
      });
    }

    if (friendship.status !== 'PENDING') {
      return reply.status(400).send({
        success: false,
        error: 'Request already processed',
      });
    }

    await prisma.friendship.update({
      where: { id },
      data: { status: 'ACCEPTED' },
    });

    return reply.send({
      success: true,
      message: 'Friend request accepted',
    });
  });

  // Reject friend request
  app.post('/reject/:id', { preHandler: authenticate }, async (request, reply) => {
    const userId = getUser(request).userId;
    const { id } = request.params as { id: string };

    const friendship = await prisma.friendship.findUnique({
      where: { id },
    });

    if (!friendship) {
      return reply.status(404).send({
        success: false,
        error: 'Friend request not found',
      });
    }

    if (friendship.friendId !== userId) {
      return reply.status(403).send({
        success: false,
        error: 'Not your friend request',
      });
    }

    await prisma.friendship.update({
      where: { id },
      data: { status: 'REJECTED' },
    });

    return reply.send({
      success: true,
      message: 'Friend request rejected',
    });
  });

  // Remove friend
  app.delete('/:id', { preHandler: authenticate }, async (request, reply) => {
    const userId = getUser(request).userId;
    const { id } = request.params as { id: string };

    // Find friendship where current user is either party
    const friendship = await prisma.friendship.findFirst({
      where: {
        OR: [
          { userId, friendId: id, status: 'ACCEPTED' },
          { userId: id, friendId: userId, status: 'ACCEPTED' },
        ],
      },
    });

    if (!friendship) {
      return reply.status(404).send({
        success: false,
        error: 'Friendship not found',
      });
    }

    await prisma.friendship.delete({
      where: { id: friendship.id },
    });

    return reply.send({
      success: true,
      message: 'Friend removed',
    });
  });
}
