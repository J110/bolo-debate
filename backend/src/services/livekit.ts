import { AccessToken } from 'livekit-server-sdk';
import { config } from '../config/index.js';

export async function getLiveKitToken(
  roomId: string,
  oderId: string,
  userName: string
): Promise<string> {
  const at = new AccessToken(config.livekit.apiKey, config.livekit.apiSecret, {
    identity: oderId,
    name: userName,
    ttl: '2h',
  });

  at.addGrant({
    room: roomId,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });

  return await at.toJwt();
}

export async function createLiveKitRoom(roomId: string): Promise<void> {
  // LiveKit automatically creates rooms when participants join
  // This function can be extended for pre-room creation if needed
  console.log(`LiveKit room will be created: ${roomId}`);
}

export async function closeLiveKitRoom(roomId: string): Promise<void> {
  // In a production environment, you'd use the LiveKit Server SDK
  // to forcefully close a room
  console.log(`LiveKit room should be closed: ${roomId}`);
}
