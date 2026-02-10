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

// Simplified regions and categories to keep
const KEEP_REGIONS = ['National', 'Delhi NCR', 'Delhi', 'Mumbai', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata'];
const KEEP_CATEGORIES = ['Politics', 'Technology', 'Business', 'Sports', 'Entertainment'];

// Cleanup old rooms on startup and populate topic cache
async function startupCleanup() {
  try {
    const { prisma } = await import('./config/database.js');
    
    console.log('🧹 Running startup cleanup...');
  
    // === SIMPLIFY REGIONS AND CATEGORIES ===
    const allRegions = await prisma.region.findMany();
    const allCategories = await prisma.category.findMany();
    
    const regionsToDelete = allRegions.filter(r => !KEEP_REGIONS.includes(r.name));
    const categoriesToDelete = allCategories.filter(c => !KEEP_CATEGORIES.includes(c.name));
    
    if (regionsToDelete.length > 0) {
      const regionIds = regionsToDelete.map(r => r.id);
      console.log(`  🗑️ Removing ${regionsToDelete.length} extra regions`);
      await prisma.topicQueue.deleteMany({ where: { regionId: { in: regionIds } } });
      await prisma.room.deleteMany({ where: { regionId: { in: regionIds } } });
      await prisma.region.deleteMany({ where: { id: { in: regionIds } } });
    }
    
    if (categoriesToDelete.length > 0) {
      const categoryIds = categoriesToDelete.map(c => c.id);
      console.log(`  🗑️ Removing ${categoriesToDelete.length} extra categories`);
      await prisma.topicQueue.deleteMany({ where: { categoryId: { in: categoryIds } } });
      await prisma.room.deleteMany({ where: { categoryId: { in: categoryIds } } });
      await prisma.category.deleteMany({ where: { id: { in: categoryIds } } });
    }
    
    // Rename "Delhi" to "Delhi NCR" if needed
    await prisma.region.updateMany({
      where: { name: 'Delhi' },
      data: { name: 'Delhi NCR' },
    });
    
    // Delete ALL AI-hosted rooms on startup
    const aiRoomsDeleted = await prisma.room.deleteMany({
      where: {
        isAiHosted: true,
        status: { in: ['LIVE', 'SCHEDULED'] },
      },
    });
    
    if (aiRoomsDeleted.count > 0) {
      console.log(`  Cleared ${aiRoomsDeleted.count} AI-hosted rooms`);
    }
    
    // Delete old ended rooms (older than 24 hours)
    const oldRoomsCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    await prisma.room.deleteMany({
      where: {
        status: 'ENDED',
        updatedAt: { lte: oldRoomsCutoff },
      },
    });
    
    // Check topic cache and populate if needed
    const cachedTopicCount = await prisma.topicQueue.count({
      where: { isUsed: false },
    });
    
    console.log(`  📦 Topic cache has ${cachedTopicCount} unused topics`);
    
    if (cachedTopicCount < 20) {
      console.log('  🎯 Generating initial batch of topics...');
      try {
        const { batchGenerateTopics } = await import('./services/ai.js');
        await batchGenerateTopics(20);
      } catch (aiError) {
        console.error('  ⚠️ AI topic generation failed:', aiError);
      }
    }
    
    // Ensure minimum rooms exist
    try {
      const { ensureMinimumRoomsPerRegion } = await import('./services/room.js');
      await ensureMinimumRoomsPerRegion();
    } catch (roomError) {
      console.error('  ⚠️ Room creation failed:', roomError);
    }
    
    console.log('✅ Startup cleanup complete');
  } catch (error) {
    console.error('⚠️ Startup cleanup failed (server will continue):', error);
  }
}

// Initialize and start server
async function start() {
  try {
    console.log('🔧 Initializing server...');
    
    // Register plugins INSIDE the async function
    await app.register(cors, {
      origin: true, // Allow all origins for now
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
    });
    console.log('  ✓ CORS enabled');

    await app.register(jwt, {
      secret: config.jwt.secret,
    });
    console.log('  ✓ JWT configured');

    await app.register(websocket);
    console.log('  ✓ WebSocket enabled');

    // Health check endpoints
    app.get('/health', async () => {
      return { status: 'ok', timestamp: new Date().toISOString(), version: '1.2.0' };
    });

    app.get('/', async () => {
      return { name: 'Bolo Debate API', status: 'running', timestamp: new Date().toISOString() };
    });

    // Self-ping to prevent Render from sleeping (every 10 minutes)
    const SELF_PING_INTERVAL = 10 * 60 * 1000; // 10 minutes
    const selfPing = async () => {
      try {
        const url = process.env.RENDER_EXTERNAL_URL || 'https://bolo-debate-api.onrender.com';
        const response = await fetch(`${url}/health`);
        if (response.ok) {
          console.log(`🏓 Self-ping successful at ${new Date().toISOString()}`);
        }
      } catch (error) {
        console.log('🏓 Self-ping failed (this is normal during startup)');
      }
    };
    
    // Start self-ping after server is ready (delayed start)
    setTimeout(() => {
      console.log('🏓 Starting self-ping to prevent sleep...');
      setInterval(selfPing, SELF_PING_INTERVAL);
    }, 60000); // Wait 1 minute before starting

    // Register API routes
    await app.register(authRoutes, { prefix: '/api/auth' });
    await app.register(userRoutes, { prefix: '/api/users' });
    await app.register(roomRoutes, { prefix: '/api/rooms' });
    await app.register(regionRoutes, { prefix: '/api/regions' });
    await app.register(categoryRoutes, { prefix: '/api/categories' });
    await app.register(friendRoutes, { prefix: '/api/friends' });
    await app.register(reportRoutes, { prefix: '/api/reports' });
    console.log('  ✓ Routes registered');

    // Setup WebSocket
    setupWebSocket(app);
    console.log('  ✓ WebSocket handlers configured');

    // Connect to database
    console.log('🔌 Connecting to database...');
    await connectDatabase();
    console.log('  ✓ Database connected');
    
    // Start listening BEFORE background tasks
    await app.listen({
      port: config.server.port,
      host: config.server.host,
    });
    console.log(`🚀 Server running at http://${config.server.host}:${config.server.port}`);

    // Start scheduler
    startScheduler();
    console.log('  ✓ Scheduler started');
    
    // Run startup cleanup in background AFTER server is listening
    setTimeout(() => {
      startupCleanup().catch(err => {
        console.error('⚠️ Background startup cleanup failed:', err);
      });
    }, 1000);

  } catch (error) {
    console.error('❌ Server startup failed:', error);
    app.log.error(error);
    process.exit(1);
  }
}

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

// Start the server
start();
