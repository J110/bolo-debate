import Redis from 'ioredis';
import { config } from './index.js';
import { EventEmitter } from 'events';

// In-memory store for local development
class MemoryStore extends EventEmitter {
  private store: Map<string, string> = new Map();
  private sets: Map<string, Set<string>> = new Map();

  async get(key: string): Promise<string | null> {
    return this.store.get(key) || null;
  }

  async set(key: string, value: string, ..._args: any[]): Promise<string> {
    this.store.set(key, value);
    return 'OK';
  }

  async del(key: string): Promise<number> {
    return this.store.delete(key) ? 1 : 0;
  }

  async sadd(key: string, member: string): Promise<number> {
    if (!this.sets.has(key)) {
      this.sets.set(key, new Set());
    }
    this.sets.get(key)!.add(member);
    return 1;
  }

  async srem(key: string, member: string): Promise<number> {
    const set = this.sets.get(key);
    if (set) {
      return set.delete(member) ? 1 : 0;
    }
    return 0;
  }

  async smembers(key: string): Promise<string[]> {
    const set = this.sets.get(key);
    return set ? Array.from(set) : [];
  }

  async quit(): Promise<string> {
    return 'OK';
  }

  subscribe(channel: string, callback?: (err: Error | null) => void): void {
    if (callback) callback(null);
  }

  publish(channel: string, message: string): void {
    this.emit('message', channel, message);
  }

  on(event: string, listener: (...args: any[]) => void): this {
    return super.on(event, listener);
  }
}

// Check if we should use memory store
const useMemory = config.redis.url === 'memory' || !config.redis.url;

let redis: any;
let redisSub: any;
let redisPub: any;

if (useMemory) {
  console.log('📦 Using in-memory store (no Redis required)');
  const memStore = new MemoryStore();
  redis = memStore;
  redisSub = memStore;
  redisPub = memStore;
} else {
  // @ts-ignore - ioredis typing issue with ESM
  const RedisClient = Redis.default || Redis;
  
  redis = new RedisClient(config.redis.url, {
    maxRetriesPerRequest: 3,
    retryStrategy(times: number) {
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
  });

  redisSub = new RedisClient(config.redis.url);
  redisPub = new RedisClient(config.redis.url);

  redis.on('connect', () => {
    console.log('✅ Redis connected');
  });

  redis.on('error', (error: Error) => {
    console.error('❌ Redis error:', error);
  });
}

export { redis, redisSub, redisPub };

// Redis key prefixes
export const REDIS_KEYS = {
  ROOM_STATE: (roomId: string) => `room:${roomId}:state`,
  ROOM_PARTICIPANTS: (roomId: string) => `room:${roomId}:participants`,
  USER_SESSION: (userId: string) => `user:${userId}:session`,
  ACTIVE_ROOMS: 'rooms:active',
  SCHEDULED_ROOMS: 'rooms:scheduled',
} as const;
