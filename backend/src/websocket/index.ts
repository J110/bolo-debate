import { FastifyInstance } from 'fastify';
import { WebSocket } from 'ws';
import { redis, redisSub, redisPub } from '../config/redis.js';
import { WebSocketMessage } from '../types/index.js';

// Map of roomId -> Set of WebSocket connections
const roomConnections = new Map<string, Set<WebSocket>>();

// Map of WebSocket -> roomId (for cleanup)
const connectionRooms = new Map<WebSocket, string>();

export function setupWebSocket(app: FastifyInstance): void {
  // Subscribe to Redis pub/sub for room events
  redisSub.subscribe('room:events', (err) => {
    if (err) {
      console.error('Failed to subscribe to room events:', err);
    } else {
      console.log('✅ Subscribed to room:events channel');
    }
  });

  redisSub.on('message', (channel, message) => {
    if (channel === 'room:events') {
      try {
        const event = JSON.parse(message) as WebSocketMessage;
        deliverToRoom(event.roomId, message);
      } catch (error) {
        console.error('Error processing Redis message:', error);
      }
    }
  });

  // WebSocket route
  app.get('/ws', { websocket: true }, (connection, request) => {
    const ws = connection;
    
    console.log('WebSocket client connected');

    ws.on('message', async (data) => {
      try {
        const message = JSON.parse(data.toString());
        await handleMessage(ws, message);
      } catch (error) {
        console.error('Error handling WebSocket message:', error);
        ws.send(JSON.stringify({ error: 'Invalid message format' }));
      }
    });

    ws.on('close', () => {
      handleDisconnect(ws);
    });

    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
      handleDisconnect(ws);
    });
  });
}

async function handleMessage(ws: WebSocket, message: any): Promise<void> {
  const { type, roomId, payload } = message;

  switch (type) {
    case 'join_room':
      joinRoom(ws, roomId);
      break;

    case 'leave_room':
      leaveRoom(ws);
      break;

    case 'ping':
      ws.send(JSON.stringify({ type: 'pong' }));
      break;

    default:
      console.log('Unknown message type:', type);
  }
}

function joinRoom(ws: WebSocket, roomId: string): void {
  // Leave any existing room first
  leaveRoom(ws);

  // Add to room connections
  if (!roomConnections.has(roomId)) {
    roomConnections.set(roomId, new Set());
  }
  roomConnections.get(roomId)!.add(ws);
  connectionRooms.set(ws, roomId);

  console.log(`Client joined room ${roomId}. Total in room: ${roomConnections.get(roomId)!.size}`);

  // Send confirmation
  ws.send(JSON.stringify({
    type: 'room:joined',
    roomId,
    timestamp: new Date().toISOString(),
  }));
}

function leaveRoom(ws: WebSocket): void {
  const roomId = connectionRooms.get(ws);
  
  if (roomId) {
    const connections = roomConnections.get(roomId);
    if (connections) {
      connections.delete(ws);
      if (connections.size === 0) {
        roomConnections.delete(roomId);
      }
    }
    connectionRooms.delete(ws);
    console.log(`Client left room ${roomId}`);
  }
}

function handleDisconnect(ws: WebSocket): void {
  leaveRoom(ws);
  console.log('WebSocket client disconnected');
}

function deliverToRoom(roomId: string, message: string): void {
  const connections = roomConnections.get(roomId);
  
  if (connections) {
    const deadConnections: WebSocket[] = [];
    
    connections.forEach((ws) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(message);
      } else {
        deadConnections.push(ws);
      }
    });

    // Clean up dead connections
    deadConnections.forEach((ws) => {
      connections.delete(ws);
      connectionRooms.delete(ws);
    });

    if (connections.size === 0) {
      roomConnections.delete(roomId);
    }
  }
}

// Function to broadcast to a room (called from other services)
export function broadcastToRoom(roomId: string, event: WebSocketMessage): void {
  // Publish to Redis so all server instances receive it
  redisPub.publish('room:events', JSON.stringify(event));
}

// Get count of connections in a room
export function getRoomConnectionCount(roomId: string): number {
  return roomConnections.get(roomId)?.size || 0;
}

// Get all active room IDs
export function getActiveRoomIds(): string[] {
  return Array.from(roomConnections.keys());
}
