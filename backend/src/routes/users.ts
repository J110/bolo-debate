import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../config/database.js';
import { authenticate } from '../middleware/auth.js';

const updateProfileSchema = z.object({
  displayName: z.string().min(1).max(50).optional(),
  avatarUrl: z.string().url().optional().nullable(),
  regionId: z.string().uuid().optional().nullable(),
});

const updatePreferencesSchema = z.object({
  categoryIds: z.array(z.string().uuid()),
});

export async function userRoutes(app: FastifyInstance) {
  // Get user profile
  app.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };

    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        createdAt: true,
        region: {
          select: { id: true, name: true, state: true },
        },
      },
    });

    if (!user) {
      return reply.status(404).send({
        success: false,
        error: 'User not found',
      });
    }

    return reply.send({
      success: true,
      data: user,
    });
  });

  // Update profile
  app.patch('/me', { preHandler: authenticate }, async (request, reply) => {
    try {
      const body = updateProfileSchema.parse(request.body);

      const user = await prisma.user.update({
        where: { id: request.user!.userId },
        data: body,
        select: {
          id: true,
          username: true,
          displayName: true,
          avatarUrl: true,
          regionId: true,
        },
      });

      return reply.send({
        success: true,
        data: user,
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

  // Update category preferences
  app.put('/me/preferences', { preHandler: authenticate }, async (request, reply) => {
    try {
      const body = updatePreferencesSchema.parse(request.body);
      const userId = request.user!.userId;

      // Delete existing preferences
      await prisma.userCategoryPreference.deleteMany({
        where: { userId },
      });

      // Create new preferences
      if (body.categoryIds.length > 0) {
        await prisma.userCategoryPreference.createMany({
          data: body.categoryIds.map(categoryId => ({
            userId,
            categoryId,
          })),
        });
      }

      const preferences = await prisma.userCategoryPreference.findMany({
        where: { userId },
        include: { category: true },
      });

      return reply.send({
        success: true,
        data: preferences.map(p => p.category),
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

  // Get user's room history
  app.get('/me/history', { preHandler: authenticate }, async (request, reply) => {
    const { page = '1', limit = '20' } = request.query as { page?: string; limit?: string };
    const pageNum = parseInt(page, 10);
    const limitNum = Math.min(parseInt(limit, 10), 50);

    const [participations, total] = await Promise.all([
      prisma.roomParticipant.findMany({
        where: { userId: request.user!.userId },
        include: {
          room: {
            include: {
              category: true,
              region: true,
              _count: { select: { participants: true } },
            },
          },
        },
        orderBy: { joinedAt: 'desc' },
        skip: (pageNum - 1) * limitNum,
        take: limitNum,
      }),
      prisma.roomParticipant.count({
        where: { userId: request.user!.userId },
      }),
    ]);

    return reply.send({
      success: true,
      data: {
        items: participations.map(p => ({
          ...p.room,
          participantCount: p.room._count.participants,
          joinedAt: p.joinedAt,
          side: p.side,
        })),
        total,
        page: pageNum,
        pageSize: limitNum,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  });
}
