import { FastifyInstance } from 'fastify';
import { redisSub, redisPub } from '../config/redis.js';
import { WebSocketMessage } from '../types/index.js';

// Store connections by room
const roomConnections = new Map<string, Set<any>>();
const connectionRooms = new Map<any, string>();

export function setupWebSocket(app: FastifyInstance): void {
  // Subscribe to Redis pub/sub for room events
  redisSub.subscribe('room:events', (err: any) => {
    if (err) {
      console.error('Failed to subscribe to room events:', err);
    } else {
      console.log('✅ Subscribed to room:events channel');
    }
  });

  redisSub.on('message', (channel: string, message: string) => {
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
  app.get('/ws', { websocket: true }, (socket: any, request) => {
    console.log('WebSocket client connected');

    socket.on('message', async (data: any) => {
      try {
        const message = JSON.parse(data.toString());
        await handleMessage(socket, message);
      } catch (error) {
        console.error('Error handling WebSocket message:', error);
        socket.send(JSON.stringify({ error: 'Invalid message format' }));
      }
    });

    socket.on('close', () => {
      handleDisconnect(socket);
    });

    socket.on('error', (error: any) => {
      console.error('WebSocket error:', error);
      handleDisconnect(socket);
    });
  });
}

async function handleMessage(ws: any, message: any): Promise<void> {
  const { type, roomId } = message;

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

function joinRoom(ws: any, roomId: string): void {
  leaveRoom(ws);

  if (!roomConnections.has(roomId)) {
    roomConnections.set(roomId, new Set());
  }
  roomConnections.get(roomId)!.add(ws);
  connectionRooms.set(ws, roomId);

  console.log(`Client joined room ${roomId}. Total in room: ${roomConnections.get(roomId)!.size}`);

  ws.send(JSON.stringify({
    type: 'room:joined',
    roomId,
    timestamp: new Date().toISOString(),
  }));
}

function leaveRoom(ws: any): void {
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

function handleDisconnect(ws: any): void {
  leaveRoom(ws);
  console.log('WebSocket client disconnected');
}

function deliverToRoom(roomId: string, message: string): void {
  const connections = roomConnections.get(roomId);
  
  if (connections) {
    const deadConnections: any[] = [];
    
    connections.forEach((ws: any) => {
      try {
        if (ws.readyState === 1) { // WebSocket.OPEN = 1
          ws.send(message);
        } else {
          deadConnections.push(ws);
        }
      } catch {
        deadConnections.push(ws);
      }
    });

    deadConnections.forEach((ws) => {
      connections.delete(ws);
      connectionRooms.delete(ws);
    });

    if (connections.size === 0) {
      roomConnections.delete(roomId);
    }
  }
}

// Broadcast to a room via Redis
export function broadcastToRoom(roomId: string, event: WebSocketMessage): void {
  redisPub.publish('room:events', JSON.stringify(event));
}

export function getRoomConnectionCount(roomId: string): number {
  return roomConnections.get(roomId)?.size || 0;
}

export function getActiveRoomIds(): string[] {
  return Array.from(roomConnections.keys());
}
