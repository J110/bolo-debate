import { FastifyInstance } from 'fastify';
import { prisma } from '../config/database.js';
import { ensureMinimumRoomsPerRegion } from '../services/room.js';
import { generateTopicsFromTrending } from '../services/ai.js';
import { refreshTrendingData, cleanupExpiredTopics, cleanupExpiredTrendingItems } from '../services/trending.js';

// Simplified regions and categories to keep
const KEEP_REGIONS = ['National', 'Delhi NCR', 'Delhi', 'Mumbai', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata'];
const KEEP_CATEGORIES = ['Politics', 'Technology', 'Business', 'Sports', 'Entertainment'];

export async function regionRoutes(app: FastifyInstance) {
  // Refresh trending data and generate new topics
  app.post('/trending/refresh', async (_request, reply) => {
    console.log('📰 Manual trending data refresh triggered...');
    
    try {
      // 1. Cleanup expired data
      const expiredTopics = await cleanupExpiredTopics();
      const expiredTrending = await cleanupExpiredTrendingItems();
      
      // 2. Fetch new trending items
      const refreshResult = await refreshTrendingData();
      
      // 3. Generate topics from trending
      const topicsResult = await generateTopicsFromTrending();
      
      // 4. Get current counts
      const totalTopics = await prisma.topicQueue.count({ where: { isUsed: false } });
      const totalTrending = await prisma.trendingItem.count({ where: { isProcessed: false } });
      
      console.log('✅ Manual trending refresh complete');
      
      return reply.send({
        success: true,
        data: {
          cleanup: {
            expiredTopics,
            expiredTrending,
          },
          refresh: refreshResult,
          topicsGenerated: topicsResult.converted,
          totals: {
            availableTopics: totalTopics,
            pendingTrendingItems: totalTrending,
          },
        },
      });
    } catch (error) {
      console.error('Error in manual trending refresh:', error);
      return reply.status(500).send({
        success: false,
        error: 'Failed to refresh trending data',
        details: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  // Get trending stats
  app.get('/trending/stats', async (_request, reply) => {
    const now = new Date();
    
    const [
      trendingCount,
      unprocessedTrending,
      availableTopics,
      topicsByCategory,
      topicsByRegion,
    ] = await Promise.all([
      prisma.trendingItem.count(),
      prisma.trendingItem.count({ where: { isProcessed: false, expiresAt: { gt: now } } }),
      prisma.topicQueue.count({ where: { isUsed: false, OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] } }),
      prisma.topicQueue.groupBy({
        by: ['categoryId'],
        where: { isUsed: false },
        _count: true,
      }),
      prisma.topicQueue.groupBy({
        by: ['regionId'],
        where: { isUsed: false },
        _count: true,
      }),
    ]);
    
    // Get category and region names
    const categories = await prisma.category.findMany();
    const regions = await prisma.region.findMany();
    
    const categoryMap = new Map(categories.map(c => [c.id, c.name]));
    const regionMap = new Map(regions.map(r => [r.id, r.name]));
    
    return reply.send({
      success: true,
      data: {
        trendingItems: {
          total: trendingCount,
          unprocessed: unprocessedTrending,
        },
        topics: {
          available: availableTopics,
          byCategory: topicsByCategory.map(t => ({
            category: categoryMap.get(t.categoryId) || 'Unknown',
            count: t._count,
          })),
          byRegion: topicsByRegion.map(t => ({
            region: regionMap.get(t.regionId) || 'Unknown',
            count: t._count,
          })),
        },
      },
    });
  });

  // Reset all rooms - regenerate fresh using available trending topics
  app.post('/reset', async (_request, reply) => {
    console.log('🔄 Resetting rooms...');
    
    const now = new Date();
    
    // Only delete USED or EXPIRED topics (preserve fresh trending topics)
    const deletedTopics = await prisma.topicQueue.deleteMany({
      where: {
        OR: [
          { isUsed: true },  // Used topics
          { usageCount: { gte: 3 } },  // Overused topics
          { expiresAt: { lt: now } },  // Expired topics
        ],
      },
    });
    console.log(`  Deleted ${deletedTopics.count} used/expired topics`);
    
    // Reset usage count on remaining topics so they can be reused
    await prisma.topicQueue.updateMany({
      where: { isUsed: false },
      data: { usageCount: 0 },
    });
    
    // Delete all AI-hosted rooms
    const deletedRooms = await prisma.room.deleteMany({
      where: { isAiHosted: true },
    });
    console.log(`  Deleted ${deletedRooms.count} AI-hosted rooms`);
    
    // Check how many topics are available
    const availableTopics = await prisma.topicQueue.count({ where: { isUsed: false } });
    console.log(`  ${availableTopics} trending topics available for room creation`);
    
    // Regenerate rooms for all regions
    console.log('  Creating fresh rooms for all regions...');
    await ensureMinimumRoomsPerRegion();
    
    // Get new counts
    const liveRooms = await prisma.room.count({ where: { status: 'LIVE' } });
    const scheduledRooms = await prisma.room.count({ where: { status: 'SCHEDULED' } });
    const regions = await prisma.region.findMany();
    
    console.log(`✅ Reset complete: ${liveRooms} live, ${scheduledRooms} scheduled rooms`);
    
    return reply.send({
      success: true,
      data: {
        deletedTopics: deletedTopics.count,
        deletedRooms: deletedRooms.count,
        availableTopics,
        newLiveRooms: liveRooms,
        newScheduledRooms: scheduledRooms,
        regions: regions.map(r => r.name),
      },
    });
  });
  // Admin endpoint to cleanup extra regions/categories and add National
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
    
    // Create "National" region if it doesn't exist (for pan-India discussions)
    const nationalExists = await prisma.region.findFirst({ where: { name: 'National' } });
    let nationalCreated = false;
    if (!nationalExists) {
      await prisma.region.create({
        data: {
          name: 'National',
          state: 'India',
          latitude: 20.5937,
          longitude: 78.9629,
        },
      });
      nationalCreated = true;
      console.log('✅ Created National region for pan-India discussions');
    }
    
    // Get remaining counts
    const remainingRegions = await prisma.region.findMany({ orderBy: { name: 'asc' } });
    const remainingCategories = await prisma.category.findMany({ orderBy: { name: 'asc' } });
    
    console.log(`✅ Cleanup complete: removed ${deletedRegions} regions, ${deletedCategories} categories`);
    
    return reply.send({
      success: true,
      data: {
        deletedRegions,
        deletedCategories,
        nationalCreated,
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
