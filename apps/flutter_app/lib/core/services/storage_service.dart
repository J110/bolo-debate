import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bolo_debate/core/constants/app_constants.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Token management (secure storage)
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.tokenKey);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
  }

  // User data (secure storage)
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _secureStorage.write(
      key: AppConstants.userKey,
      value: jsonEncode(userData),
    );
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final data = await _secureStorage.read(key: AppConstants.userKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> deleteUserData() async {
    await _secureStorage.delete(key: AppConstants.userKey);
  }

  // Selected region (shared preferences)
  Future<void> saveSelectedRegion(String? regionId) async {
    final prefs = await SharedPreferences.getInstance();
    if (regionId != null) {
      await prefs.setString(AppConstants.regionKey, regionId);
    } else {
      await prefs.remove(AppConstants.regionKey);
    }
  }

  Future<String?> getSelectedRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.regionKey);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
