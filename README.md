# Bolo Debate

An audio debate and discussion platform for India, where users can join live audio rooms to discuss trending local news topics.

## Features

- **Live Audio Debates**: Join rooms with two opposing sides and debate on trending topics
- **Discussion Rooms**: Open conversations without sides for collaborative discussions
- **Local News Topics**: AI-generated topics based on regional trending news
- **Real-time Chat**: Text chat during audio sessions
- **Reactions**: React to discussions with emojis
- **AI Bot Suggestions**: Get debate point suggestions during discussions
- **Anonymous Profiles**: Username-based anonymous participation
- **Friends System**: Connect with other debaters
- **Host Controls**: Extend time, manage participants, get hosting tips

## Tech Stack

### Backend
- **Runtime**: Node.js with TypeScript
- **Framework**: Fastify
- **Database**: PostgreSQL with Prisma ORM
- **Cache/PubSub**: Redis
- **Audio**: LiveKit (self-hosted)
- **AI**: OpenAI GPT-4

### Frontend
- **Framework**: Flutter
- **State Management**: Riverpod
- **Navigation**: go_router
- **Audio SDK**: livekit_client

## Project Structure

```
bolo-debate/
├── apps/
│   └── flutter_app/           # Flutter mobile/web app
├── backend/
│   ├── src/
│   │   ├── config/            # Configuration
│   │   ├── routes/            # API endpoints
│   │   ├── services/          # Business logic
│   │   ├── websocket/         # Real-time events
│   │   └── jobs/              # Scheduled tasks
│   └── prisma/                # Database schema
└── docker-compose.yml         # Local development services
```

## Getting Started

### Prerequisites

- Node.js 18+
- Flutter 3.5+
- Docker and Docker Compose
- PostgreSQL (via Docker)
- Redis (via Docker)

### Backend Setup

1. Start the services:
```bash
docker-compose up -d
```

2. Install dependencies:
```bash
cd backend
npm install
```

3. Setup environment:
```bash
cp .env.example .env
# Edit .env with your API keys
```

4. Initialize database:
```bash
npm run db:push
npm run db:seed
```

5. Start the server:
```bash
npm run dev
```

### Flutter App Setup

1. Install dependencies:
```bash
cd apps/flutter_app
flutter pub get
```

2. Run the app:
```bash
flutter run
```

## API Documentation

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user

### Rooms
- `GET /api/rooms` - List rooms
- `GET /api/rooms/live` - Get live rooms
- `GET /api/rooms/scheduled` - Get scheduled rooms
- `POST /api/rooms` - Create room
- `POST /api/rooms/:id/join` - Join room
- `POST /api/rooms/:id/leave` - Leave room
- `GET /api/rooms/:id/token` - Get LiveKit token

### Friends
- `GET /api/friends` - List friends
- `POST /api/friends/request` - Send friend request
- `POST /api/friends/accept/:id` - Accept request

## Environment Variables

```env
DATABASE_URL=postgresql://...
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
LIVEKIT_URL=ws://localhost:7880
OPENAI_API_KEY=your-openai-key
```

## Room Lifecycle

1. **Scheduled**: Room is created 30+ minutes in advance
2. **Live**: Room is active for 30 minutes
3. **Extended**: Host can extend up to 3 times (5 min each)
4. **Ended**: Room closes automatically

## AI Features

- **Topic Generation**: Creates debate topics from trending news
- **Bot Suggestions**: Provides talking points during debates
- **Subtopics**: Suggests related topics for hosts
- **Auto-scheduling**: Maintains 5 live rooms per region

## License

MIT
