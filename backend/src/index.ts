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

// Cleanup old rooms on startup
async function startupCleanup() {
  const { prisma } = await import('./config/database.js');
  
  console.log('🧹 Running startup cleanup...');
  
  // End all rooms that have been live for over 45 minutes
  const maxLiveTime = 45 * 60 * 1000;
  const cutoffTime = new Date(Date.now() - maxLiveTime);
  
  const staleResult = await prisma.room.updateMany({
    where: {
      status: 'LIVE',
      startedAt: { lte: cutoffTime },
    },
    data: { status: 'ENDED' },
  });
  
  if (staleResult.count > 0) {
    console.log(`  Ended ${staleResult.count} stale live rooms`);
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
  
  // Now ensure minimum rooms exist
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
