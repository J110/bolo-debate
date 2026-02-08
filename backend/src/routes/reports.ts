import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../config/database.js';
import { authenticate, getUser } from '../middleware/auth.js';

const createReportSchema = z.object({
  reportedUserId: z.string().uuid(),
  roomId: z.string().uuid().optional(),
  reason: z.string().min(10).max(1000),
});

export async function reportRoutes(app: FastifyInstance) {
  // Create report
  app.post('/', { preHandler: authenticate }, async (request, reply) => {
    try {
      const body = createReportSchema.parse(request.body);
      const userId = getUser(request).userId;

      if (body.reportedUserId === userId) {
        return reply.status(400).send({
          success: false,
          error: 'Cannot report yourself',
        });
      }

      // Verify reported user exists
      const reportedUser = await prisma.user.findUnique({
        where: { id: body.reportedUserId },
      });

      if (!reportedUser) {
        return reply.status(404).send({
          success: false,
          error: 'User not found',
        });
      }

      // Check if already reported in the same room
      if (body.roomId) {
        const existingReport = await prisma.report.findFirst({
          where: {
            reporterId: userId,
            reportedUserId: body.reportedUserId,
            roomId: body.roomId,
            status: 'PENDING',
          },
        });

        if (existingReport) {
          return reply.status(400).send({
            success: false,
            error: 'Already reported this user in this room',
          });
        }
      }

      const report = await prisma.report.create({
        data: {
          reporterId: userId,
          reportedUserId: body.reportedUserId,
          roomId: body.roomId,
          reason: body.reason,
        },
      });

      return reply.status(201).send({
        success: true,
        data: report,
        message: 'Report submitted successfully',
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

  // Get user's reports (for transparency)
  app.get('/my', { preHandler: authenticate }, async (request, reply) => {
    const userId = getUser(request).userId;

    const reports = await prisma.report.findMany({
      where: { reporterId: userId },
      select: {
        id: true,
        reason: true,
        status: true,
        createdAt: true,
        reportedUser: {
          select: { id: true, username: true, displayName: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return reply.send({
      success: true,
      data: reports,
    });
  });
}
