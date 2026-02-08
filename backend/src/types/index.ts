// JWT payload type
export interface JWTPayload {
  userId: string;
  username: string;
}

// Augment Fastify JWT
declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: JWTPayload;
    user: JWTPayload;
  }
}

// Room participant info
export interface ParticipantInfo {
  id: string;
  oderId: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  side: 'A' | 'B' | 'NEUTRAL';
  role: 'HOST' | 'SPEAKER' | 'LISTENER';
  handRaised: boolean;
  isMuted: boolean;
}

// Room state for real-time updates
export interface RoomState {
  id: string;
  title: string;
  status: 'SCHEDULED' | 'LIVE' | 'ENDED';
  type: 'DEBATE' | 'DISCUSSION';
  sideALabel: string | null;
  sideBLabel: string | null;
  participantCount: number;
  sideACount: number;
  sideBCount: number;
  scheduledAt: string;
  startedAt: string | null;
  endsAt: string | null;
  extensionsUsed: number;
}

// WebSocket event types
export type WebSocketEventType =
  | 'room:join'
  | 'room:leave'
  | 'room:update'
  | 'participant:joined'
  | 'participant:left'
  | 'participant:updated'
  | 'message:new'
  | 'reaction:new'
  | 'hand:raised'
  | 'hand:lowered'
  | 'speaker:changed'
  | 'ai:suggestion'
  | 'room:ending_soon'
  | 'room:ended';

export interface WebSocketMessage<T = unknown> {
  type: WebSocketEventType;
  roomId: string;
  payload: T;
  timestamp: string;
}

// API response types
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

// Room creation input
export interface CreateRoomInput {
  title: string;
  description?: string;
  regionId: string;
  categoryId: string;
  type: 'DEBATE' | 'DISCUSSION';
  sideALabel?: string;
  sideBLabel?: string;
  scheduledAt: string;
}

// Join room input
export interface JoinRoomInput {
  side?: 'A' | 'B' | 'NEUTRAL';
  pledgeAccepted: boolean;
}
