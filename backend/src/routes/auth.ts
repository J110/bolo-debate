import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../config/database.js';
import { config } from '../config/index.js';
import { authenticate, getUser } from '../middleware/auth.js';

const registerSchema = z.object({
  username: z.string().min(3).max(20).regex(/^[a-zA-Z0-9_]+$/, 
    'Username can only contain letters, numbers, and underscores'),
  displayName: z.string().min(1).max(50),
  regionId: z.string().uuid().optional(),
});

const loginSchema = z.object({
  username: z.string(),
});

export async function authRoutes(app: FastifyInstance) {
  // Register new user
  app.post('/register', async (request, reply) => {
    try {
      const body = registerSchema.parse(request.body);

      // Check if username exists
      const existing = await prisma.user.findUnique({
        where: { username: body.username.toLowerCase() },
      });

      if (existing) {
        return reply.status(400).send({
          success: false,
          error: 'Username already taken',
        });
      }

      // Create user
      const user = await prisma.user.create({
        data: {
          username: body.username.toLowerCase(),
          displayName: body.displayName,
          regionId: body.regionId,
        },
      });

      // Generate token
      const token = app.jwt.sign(
        { userId: user.id, username: user.username },
        { expiresIn: config.jwt.expiresIn }
      );

      return reply.status(201).send({
        success: true,
        data: {
          user: {
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            regionId: user.regionId,
          },
          token,
        },
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

  // Login (just username - anonymous auth)
  app.post('/login', async (request, reply) => {
    try {
      const body = loginSchema.parse(request.body);

      const user = await prisma.user.findUnique({
        where: { username: body.username.toLowerCase() },
      });

      if (!user) {
        return reply.status(401).send({
          success: false,
          error: 'User not found',
        });
      }

      if (user.isBanned) {
        return reply.status(403).send({
          success: false,
          error: 'User is banned',
        });
      }

      const token = app.jwt.sign(
        { userId: user.id, username: user.username },
        { expiresIn: config.jwt.expiresIn }
      );

      return reply.send({
        success: true,
        data: {
          user: {
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            regionId: user.regionId,
          },
          token,
        },
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

  // Check username availability
  app.get('/check/:username', async (request, reply) => {
    const { username } = request.params as { username: string };

    const existing = await prisma.user.findUnique({
      where: { username: username.toLowerCase() },
    });

    return reply.send({
      success: true,
      data: { available: !existing },
    });
  });

  // Get current user
  app.get('/me', { preHandler: authenticate }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: getUser(request).userId },
      include: {
        region: true,
        categoryPreferences: {
          include: { category: true },
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
      data: {
        id: user.id,
        username: user.username,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        region: user.region,
        categoryPreferences: user.categoryPreferences.map(p => p.category),
      },
    });
  });

  // Refresh token
  app.post('/refresh', { preHandler: authenticate }, async (request, reply) => {
    const token = app.jwt.sign(
      { userId: getUser(request).userId, username: getUser(request).username },
      { expiresIn: config.jwt.expiresIn }
    );

    return reply.send({
      success: true,
      data: { token },
    });
  });
}
