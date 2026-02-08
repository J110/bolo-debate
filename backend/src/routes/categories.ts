import { FastifyInstance } from 'fastify';
import { prisma } from '../config/database.js';

export async function categoryRoutes(app: FastifyInstance) {
  // Get all categories
  app.get('/', async (_request, reply) => {
    const categories = await prisma.category.findMany({
      orderBy: { name: 'asc' },
    });

    return reply.send({
      success: true,
      data: categories,
    });
  });

  // Get category with room count
  app.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };

    const category = await prisma.category.findUnique({
      where: { id },
      include: {
        _count: {
          select: { rooms: true },
        },
      },
    });

    if (!category) {
      return reply.status(404).send({
        success: false,
        error: 'Category not found',
      });
    }

    return reply.send({
      success: true,
      data: {
        ...category,
        roomCount: category._count.rooms,
      },
    });
  });

  // Get categories with live room counts
  app.get('/stats/live', async (_request, reply) => {
    const stats = await prisma.room.groupBy({
      by: ['categoryId'],
      where: { status: 'LIVE' },
      _count: true,
    });

    const categories = await prisma.category.findMany();

    const result = categories.map(category => ({
      ...category,
      liveRooms: stats.find(s => s.categoryId === category.id)?._count || 0,
    }));

    return reply.send({
      success: true,
      data: result,
    });
  });
}
