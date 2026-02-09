import { FastifyInstance } from 'fastify';
import { prisma } from '../config/database.js';

// Simplified regions and categories to keep
const KEEP_REGIONS = ['Delhi NCR', 'Delhi', 'Mumbai', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata'];
const KEEP_CATEGORIES = ['Politics', 'Technology', 'Business', 'Sports', 'Entertainment'];

export async function regionRoutes(app: FastifyInstance) {
  // Admin endpoint to cleanup extra regions/categories
  app.post('/cleanup', async (_request, reply) => {
    console.log('🧹 Running manual cleanup...');
    
    // Get all regions and categories
    const allRegions = await prisma.region.findMany();
    const allCategories = await prisma.category.findMany();
    
    // Find items to delete
    const regionsToDelete = allRegions.filter(r => !KEEP_REGIONS.includes(r.name));
    const categoriesToDelete = allCategories.filter(c => !KEEP_CATEGORIES.includes(c.name));
    
    let deletedRegions = 0;
    let deletedCategories = 0;
    
    if (regionsToDelete.length > 0) {
      const regionIds = regionsToDelete.map(r => r.id);
      
      // Delete associated data
      await prisma.topicQueue.deleteMany({ where: { regionId: { in: regionIds } } });
      await prisma.room.deleteMany({ where: { regionId: { in: regionIds } } });
      const result = await prisma.region.deleteMany({ where: { id: { in: regionIds } } });
      deletedRegions = result.count;
    }
    
    if (categoriesToDelete.length > 0) {
      const categoryIds = categoriesToDelete.map(c => c.id);
      
      // Delete associated data
      await prisma.topicQueue.deleteMany({ where: { categoryId: { in: categoryIds } } });
      await prisma.room.deleteMany({ where: { categoryId: { in: categoryIds } } });
      const result = await prisma.category.deleteMany({ where: { id: { in: categoryIds } } });
      deletedCategories = result.count;
    }
    
    // Rename "Delhi" to "Delhi NCR" if needed
    await prisma.region.updateMany({
      where: { name: 'Delhi' },
      data: { name: 'Delhi NCR' },
    });
    
    // Get remaining counts
    const remainingRegions = await prisma.region.findMany();
    const remainingCategories = await prisma.category.findMany();
    
    console.log(`✅ Cleanup complete: removed ${deletedRegions} regions, ${deletedCategories} categories`);
    
    return reply.send({
      success: true,
      data: {
        deletedRegions,
        deletedCategories,
        remainingRegions: remainingRegions.map(r => r.name),
        remainingCategories: remainingCategories.map(c => c.name),
      },
    });
  });
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
