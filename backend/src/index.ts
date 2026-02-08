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

// Start server
async function start() {
  try {
    // Connect to database
    await connectDatabase();

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
