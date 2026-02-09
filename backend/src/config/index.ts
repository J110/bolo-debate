import { z } from 'zod';
import { config as dotenvConfig } from 'dotenv';

// Load .env file
dotenvConfig();

const envSchema = z.object({
  DATABASE_URL: z.string().default('file:./prisma/dev.db'),
  REDIS_URL: z.string().default('memory'),
  JWT_SECRET: z.string().default('local-dev-secret-key-12345'),
  JWT_EXPIRES_IN: z.string().default('7d'),
  LIVEKIT_API_KEY: z.string().default('devkey'),
  LIVEKIT_API_SECRET: z.string().default('secret'),
  LIVEKIT_URL: z.string().default('ws://localhost:7880'),
  OPENAI_API_KEY: z.string().default(''),
  GROQ_API_KEY: z.string().default(''),
  OLLAMA_URL: z.string().default('http://localhost:11434'),
  // News/Trending APIs
  GNEWS_API_KEY: z.string().default(''),
  NEWSAPI_KEY: z.string().default(''),
  // Image APIs
  PIXABAY_API_KEY: z.string().default(''),
  PORT: z.string().default('3000'),
  HOST: z.string().default('0.0.0.0'),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('⚠️ Environment validation warnings:', parsed.error.flatten().fieldErrors);
  console.log('Using default values for missing variables...');
}

// Use defaults for any missing values
const env = {
  DATABASE_URL: process.env.DATABASE_URL || 'file:./prisma/dev.db',
  REDIS_URL: process.env.REDIS_URL || 'memory',
  JWT_SECRET: process.env.JWT_SECRET || 'local-dev-secret-key-12345',
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
  LIVEKIT_API_KEY: process.env.LIVEKIT_API_KEY || 'devkey',
  LIVEKIT_API_SECRET: process.env.LIVEKIT_API_SECRET || 'secret',
  LIVEKIT_URL: process.env.LIVEKIT_URL || 'ws://localhost:7880',
  OPENAI_API_KEY: process.env.OPENAI_API_KEY || '',
  GROQ_API_KEY: process.env.GROQ_API_KEY || '',
  OLLAMA_URL: process.env.OLLAMA_URL || 'http://localhost:11434',
  GNEWS_API_KEY: process.env.GNEWS_API_KEY || '',
  NEWSAPI_KEY: process.env.NEWSAPI_KEY || '',
  PIXABAY_API_KEY: process.env.PIXABAY_API_KEY || '',
  PORT: process.env.PORT || '3000',
  HOST: process.env.HOST || '0.0.0.0',
  NODE_ENV: (process.env.NODE_ENV as 'development' | 'production' | 'test') || 'development',
};

export const config = {
  database: {
    url: env.DATABASE_URL,
  },
  redis: {
    url: env.REDIS_URL,
  },
  jwt: {
    secret: env.JWT_SECRET,
    expiresIn: env.JWT_EXPIRES_IN,
  },
  livekit: {
    apiKey: env.LIVEKIT_API_KEY,
    apiSecret: env.LIVEKIT_API_SECRET,
    url: env.LIVEKIT_URL,
  },
  openai: {
    apiKey: env.OPENAI_API_KEY,
  },
  groq: {
    apiKey: env.GROQ_API_KEY,
  },
  ollama: {
    url: env.OLLAMA_URL,
  },
  news: {
    gnewsApiKey: env.GNEWS_API_KEY,
    newsapiKey: env.NEWSAPI_KEY,
  },
  pixabay: {
    apiKey: env.PIXABAY_API_KEY,
  },
  server: {
    port: parseInt(env.PORT, 10),
    host: env.HOST,
    isDev: env.NODE_ENV === 'development',
    isProd: env.NODE_ENV === 'production',
  },
} as const;

export type Config = typeof config;
