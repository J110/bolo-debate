import { FastifyInstance } from 'fastify';
import { prisma } from '../config/database.js';

export async function regionRoutes(app: FastifyInstance) {
  // Get all regions
  app.get('/', async (request, reply) => {
    const { state } = request.query as { state?: string };

    const regions = await prisma.region.findMany({
      where: state ? { state } : undefined,
      orderBy: [{ state: 'asc' }, { name: 'asc' }],
    });

    return reply.send({
      success: true,
      data: regions,
    });
  });

  // Get regions grouped by state
  app.get('/grouped', async (_request, reply) => {
    const regions = await prisma.region.findMany({
      orderBy: [{ state: 'asc' }, { name: 'asc' }],
    });

    // Group by state
    const grouped = regions.reduce((acc, region) => {
      if (!acc[region.state]) {
        acc[region.state] = [];
      }
      acc[region.state].push(region);
      return acc;
    }, {} as Record<string, typeof regions>);

    return reply.send({
      success: true,
      data: grouped,
    });
  });

  // Get single region with stats
  app.get('/:id', async (request, reply) => {
    const { id } = request.params as { id: string };

    const region = await prisma.region.findUnique({
      where: { id },
      include: {
        _count: {
          select: {
            users: true,
            rooms: true,
          },
        },
      },
    });

    if (!region) {
      return reply.status(404).send({
        success: false,
        error: 'Region not found',
      });
    }

    return reply.send({
      success: true,
      data: {
        ...region,
        userCount: region._count.users,
        roomCount: region._count.rooms,
      },
    });
  });

  // Get live rooms count per region
  app.get('/stats/live', async (_request, reply) => {
    const stats = await prisma.room.groupBy({
      by: ['regionId'],
      where: { status: 'LIVE' },
      _count: true,
    });

    const regions = await prisma.region.findMany();

    const result = regions.map(region => ({
      ...region,
      liveRooms: stats.find(s => s.regionId === region.id)?._count || 0,
    }));

    return reply.send({
      success: true,
      data: result,
    });
  });
}
