import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import websocket from '@fastify/websocket';
import { config } from './config/index.js';
import { connectDatabase, disconnectDatabase } from './config/database.js';
import { redis } from './config/redis.js';

// Import routes
import { authRoutes } from './routes/auth.js';
import { userRoutes } from './routes/users.js';
import { roomRoutes } from './routes/rooms.js';
import { regionRoutes } from './routes/regions.js';
import { categoryRoutes } from './routes/categories.js';
import { friendRoutes } from './routes/friends.js';
import { reportRoutes } from './routes/reports.js';

// Import WebSocket handler
import { setupWebSocket } from './websocket/index.js';

// Import scheduler
import { startScheduler } from './jobs/scheduler.js';

const app = Fastify({
  logger: config.server.isDev ? {
    transport: {
      target: 'pino-pretty',
      options: {
        colorize: true,
      },
    },
  } : true,
});

// Register plugins
await app.register(cors, {
  origin: true,
  credentials: true,
});

await app.register(jwt, {
  secret: config.jwt.secret,
});

await app.register(websocket);

// Health check
app.get('/health', async () => {
  return { status: 'ok', timestamp: new Date().toISOString() };
});

// Register routes
app.register(authRoutes, { prefix: '/api/auth' });
app.register(userRoutes, { prefix: '/api/users' });
app.register(roomRoutes, { prefix: '/api/rooms' });
app.register(regionRoutes, { prefix: '/api/regions' });
app.register(categoryRoutes, { prefix: '/api/categories' });
app.register(friendRoutes, { prefix: '/api/friends' });
app.register(reportRoutes, { prefix: '/api/reports' });

// Setup WebSocket
setupWebSocket(app);

// Graceful shutdown
const signals: NodeJS.Signals[] = ['SIGINT', 'SIGTERM'];
signals.forEach((signal) => {
  process.on(signal, async () => {
    console.log(`\n${signal} received, shutting down gracefully...`);
    await app.close();
    await disconnectDatabase();
    await redis.quit();
    process.exit(0);
  });
});

// Simplified regions and categories to keep
const KEEP_REGIONS = ['National', 'Delhi NCR', 'Delhi', 'Mumbai', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata'];
const KEEP_CATEGORIES = ['Politics', 'Technology', 'Business', 'Sports', 'Entertainment'];

// Cleanup old rooms on startup and populate topic cache
async function startupCleanup() {
  const { prisma } = await import('./config/database.js');
  const { batchGenerateTopics } = await import('./services/ai.js');
  
  console.log('🧹 Running startup cleanup...');
  
  // === SIMPLIFY REGIONS AND CATEGORIES ===
  // Get all regions and categories
  const allRegions = await prisma.region.findMany();
  const allCategories = await prisma.category.findMany();
  
  // Find items to delete
  const regionsToDelete = allRegions.filter(r => !KEEP_REGIONS.includes(r.name));
  const categoriesToDelete = allCategories.filter(c => !KEEP_CATEGORIES.includes(c.name));
  
  if (regionsToDelete.length > 0) {
    const regionIds = regionsToDelete.map(r => r.id);
    console.log(`  🗑️ Removing ${regionsToDelete.length} extra regions: ${regionsToDelete.map(r => r.name).join(', ')}`);
    
    // Delete associated data
    await prisma.topicQueue.deleteMany({ where: { regionId: { in: regionIds } } });
    await prisma.room.deleteMany({ where: { regionId: { in: regionIds } } });
    await prisma.region.deleteMany({ where: { id: { in: regionIds } } });
  }
  
  if (categoriesToDelete.length > 0) {
    const categoryIds = categoriesToDelete.map(c => c.id);
    console.log(`  🗑️ Removing ${categoriesToDelete.length} extra categories: ${categoriesToDelete.map(c => c.name).join(', ')}`);
    
    // Delete associated data
    await prisma.topicQueue.deleteMany({ where: { categoryId: { in: categoryIds } } });
    await prisma.room.deleteMany({ where: { categoryId: { in: categoryIds } } });
    await prisma.category.deleteMany({ where: { id: { in: categoryIds } } });
  }
  
  // Rename "Delhi" to "Delhi NCR" if needed
  await prisma.region.updateMany({
    where: { name: 'Delhi' },
    data: { name: 'Delhi NCR' },
  });
  
  // === CLEANUP OLD ROOMS ===
  // Delete ALL AI-hosted rooms on startup - they'll be recreated with proper staggering
  // This ensures rooms have correctly staggered times after server restart
  const aiRoomsDeleted = await prisma.room.deleteMany({
    where: {
      isAiHosted: true,
      status: { in: ['LIVE', 'SCHEDULED'] },
    },
  });
  
  if (aiRoomsDeleted.count > 0) {
    console.log(`  Cleared ${aiRoomsDeleted.count} AI-hosted rooms (will recreate with proper timing)`);
  }
  
  // Delete old ended rooms (older than 24 hours)
  const oldRoomsCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const deletedResult = await prisma.room.deleteMany({
    where: {
      status: 'ENDED',
      updatedAt: { lte: oldRoomsCutoff },
    },
  });
  
  if (deletedResult.count > 0) {
    console.log(`  Deleted ${deletedResult.count} old ended rooms`);
  }
  
  // Check topic cache and populate if needed
  const cachedTopicCount = await prisma.topicQueue.count({
    where: { isUsed: false },
  });
  
  console.log(`  📦 Topic cache has ${cachedTopicCount} unused topics`);
  
  if (cachedTopicCount < 20) {
    console.log('  🎯 Generating initial batch of topics...');
    // Generate 20 topics initially (enough for ~2 hours at 5 live rooms)
    await batchGenerateTopics(20);
  }
  
  // Now ensure minimum rooms exist - this will create fresh rooms with proper staggering
  const { ensureMinimumRoomsPerRegion } = await import('./services/room.js');
  await ensureMinimumRoomsPerRegion();
  
  console.log('✅ Startup cleanup complete');
}

// Start server
async function start() {
  try {
    // Connect to database
    await connectDatabase();
    
    // Run startup cleanup
    await startupCleanup();

    // Start the scheduler
    startScheduler();

    // Start listening
    await app.listen({
      port: config.server.port,
      host: config.server.host,
    });

    console.log(`🚀 Server running at http://${config.server.host}:${config.server.port}`);
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
}

start();
