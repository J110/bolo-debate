import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bolo_debate/core/services/api_service.dart';
import 'package:bolo_debate/core/services/storage_service.dart';
import 'package:bolo_debate/shared/models/user_model.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final StorageService _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final token = await _storage.getToken();
      if (token != null) {
        final response = await _api.getMe();
        if (response['success'] == true) {
          final user = User.fromJson(response['data']);
          state = AuthState(user: user);
          return;
        }
      }
    } catch (e) {
      // Token invalid or expired
      await _storage.clearAll();
    }
    state = const AuthState();
  }

  Future<void> register({
    required String username,
    required String displayName,
    String? regionId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.register(
        username: username,
        displayName: displayName,
        regionId: regionId,
      );

      if (response['success'] == true) {
        final data = response['data'];
        await _storage.saveToken(data['token']);
        await _storage.saveUserData(data['user']);
        state = AuthState(user: User.fromJson(data['user']));
      } else {
        state = state.copyWith(isLoading: false, error: response['error']);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> login(String username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.login(username);

      if (response['success'] == true) {
        final data = response['data'];
        await _storage.saveToken(data['token']);
        await _storage.saveUserData(data['user']);
        state = AuthState(user: User.fromJson(data['user']));
      } else {
        state = state.copyWith(isLoading: false, error: response['error']);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> checkUsername(String username) async {
    try {
      final response = await _api.checkUsername(username);
      return response['data']['available'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});
