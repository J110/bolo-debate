import 'package:bolo_debate/shared/models/room_model.dart';

/// Returns a canonical image URL for a room:
/// 1. If backend provided `illustrationUrl` use it
/// 2. Else use a deterministic picsum seed based on room id
String getCanonicalRoomImageUrl(Room room, {int width = 640, int height = 300}) {
  if (room.illustrationUrl != null && room.illustrationUrl!.isNotEmpty) {
    return room.illustrationUrl!;
  }
  return 'https://picsum.photos/seed/${room.id}/$width/$height';
}

