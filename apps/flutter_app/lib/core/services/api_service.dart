import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bolo_debate/core/constants/app_constants.dart';
import 'package:bolo_debate/core/services/storage_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
});

class AuthInterceptor extends Interceptor {
  final Ref ref;

  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final storage = ref.read(storageServiceProvider);
    final token = await storage.getToken();
    
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid - clear storage and redirect to login
      final storage = ref.read(storageServiceProvider);
      await storage.clearAll();
      // Router will handle redirect via auth state
    }
    handler.next(err);
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider));
});

class ApiService {
  final Dio _dio;

  ApiService(this._dio);

  // Auth
  Future<Map<String, dynamic>> register({
    required String username,
    required String displayName,
    String? regionId,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'displayName': displayName,
      if (regionId != null) 'regionId': regionId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> login(String username) async {
    final response = await _dio.post('/auth/login', data: {
      'username': username,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    final response = await _dio.get('/auth/check/$username');
    return response.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  // Rooms
  Future<Map<String, dynamic>> getRooms({
    String? regionId,
    String? categoryId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get('/rooms', queryParameters: {
      if (regionId != null) 'regionId': regionId,
      if (categoryId != null) 'categoryId': categoryId,
      if (status != null) 'status': status,
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getLiveRooms({String? regionId, String? categoryId, int limit = 10}) async {
    final response = await _dio.get('/rooms/live', queryParameters: {
      if (regionId != null) 'regionId': regionId,
      if (categoryId != null) 'categoryId': categoryId,
      'limit': limit,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getScheduledRooms({String? regionId, String? categoryId, int limit = 10}) async {
    final response = await _dio.get('/rooms/scheduled', queryParameters: {
      if (regionId != null) 'regionId': regionId,
      if (categoryId != null) 'categoryId': categoryId,
      'limit': limit,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getRoom(String id) async {
    final response = await _dio.get('/rooms/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createRoom({
    required String title,
    String? description,
    required String regionId,
    required String categoryId,
    required String type,
    String? sideALabel,
    String? sideBLabel,
    required DateTime scheduledAt,
  }) async {
    final response = await _dio.post('/rooms', data: {
      'title': title,
      if (description != null) 'description': description,
      'regionId': regionId,
      'categoryId': categoryId,
      'type': type,
      if (sideALabel != null) 'sideALabel': sideALabel,
      if (sideBLabel != null) 'sideBLabel': sideBLabel,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    });
    return response.data;
  }

  Future<Map<String, dynamic>> joinRoom(String roomId, {String? side, required bool pledgeAccepted}) async {
    final response = await _dio.post('/rooms/$roomId/join', data: {
      if (side != null) 'side': side,
      'pledgeAccepted': pledgeAccepted,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> leaveRoom(String roomId) async {
    final response = await _dio.post('/rooms/$roomId/leave');
    return response.data;
  }

  Future<Map<String, dynamic>> getRoomToken(String roomId) async {
    final response = await _dio.get('/rooms/$roomId/token');
    return response.data;
  }

  Future<Map<String, dynamic>> raiseHand(String roomId, bool raised) async {
    final response = await _dio.post('/rooms/$roomId/hand', data: {'raised': raised});
    return response.data;
  }

  Future<Map<String, dynamic>> toggleMute(String roomId, bool muted) async {
    final response = await _dio.post('/rooms/$roomId/mute', data: {'muted': muted});
    return response.data;
  }

  Future<Map<String, dynamic>> extendRoom(String roomId) async {
    final response = await _dio.post('/rooms/$roomId/extend', data: {});
    return response.data;
  }

  Future<Map<String, dynamic>> claimHost(String roomId) async {
    final response = await _dio.post('/rooms/$roomId/claim-host', data: {});
    return response.data;
  }

  Future<void> kickParticipant(String roomId, String oderId) async {
    await _dio.delete('/rooms/$roomId/kick/$oderId');
  }

  // Messages
  Future<Map<String, dynamic>> getMessages(String roomId, {int limit = 50, String? before}) async {
    final response = await _dio.get('/rooms/$roomId/messages', queryParameters: {
      'limit': limit,
      if (before != null) 'before': before,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> sendMessage(String roomId, String content) async {
    final response = await _dio.post('/rooms/$roomId/messages', data: {'content': content});
    return response.data;
  }

  // Reactions
  Future<Map<String, dynamic>> sendReaction(String roomId, String emoji) async {
    final response = await _dio.post('/rooms/$roomId/reactions', data: {'emoji': emoji});
    return response.data;
  }

  // Regions & Categories
  Future<Map<String, dynamic>> getRegions() async {
    final response = await _dio.get('/regions');
    return response.data;
  }

  Future<Map<String, dynamic>> getCategories() async {
    final response = await _dio.get('/categories');
    return response.data;
  }

  // Users
  Future<Map<String, dynamic>> updateProfile({String? displayName, String? avatarUrl, String? regionId}) async {
    final response = await _dio.patch('/users/me', data: {
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (regionId != null) 'regionId': regionId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> updatePreferences(List<String> categoryIds) async {
    final response = await _dio.put('/users/me/preferences', data: {
      'categoryIds': categoryIds,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getRoomHistory({int page = 1, int limit = 20}) async {
    final response = await _dio.get('/users/me/history', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  // Friends
  Future<Map<String, dynamic>> getFriends() async {
    final response = await _dio.get('/friends');
    return response.data;
  }

  Future<Map<String, dynamic>> getFriendRequests() async {
    final response = await _dio.get('/friends/requests');
    return response.data;
  }

  Future<Map<String, dynamic>> sendFriendRequest(String username) async {
    final response = await _dio.post('/friends/request', data: {'username': username});
    return response.data;
  }

  Future<void> acceptFriendRequest(String requestId) async {
    await _dio.post('/friends/accept/$requestId');
  }

  Future<void> rejectFriendRequest(String requestId) async {
    await _dio.post('/friends/reject/$requestId');
  }

  Future<void> removeFriend(String friendId) async {
    await _dio.delete('/friends/$friendId');
  }

  // Reports
  Future<Map<String, dynamic>> reportUser({
    required String reportedUserId,
    String? roomId,
    required String reason,
  }) async {
    final response = await _dio.post('/reports', data: {
      'reportedUserId': reportedUserId,
      if (roomId != null) 'roomId': roomId,
      'reason': reason,
    });
    return response.data;
  }
}
