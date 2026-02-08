import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bolo_debate/core/services/api_service.dart';
import 'package:bolo_debate/core/services/storage_service.dart';
import 'package:bolo_debate/shared/models/room_model.dart';

// Regions provider
final regionsProvider = FutureProvider<List<Region>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getRegions();
  
  if (response['success'] == true) {
    final data = response['data'] as List;
    return data.map((json) => Region.fromJson(json)).toList();
  }
  return [];
});

// Categories provider
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getCategories();
  
  if (response['success'] == true) {
    final data = response['data'] as List;
    return data.map((json) => Category.fromJson(json)).toList();
  }
  return [];
});

// Selected region provider
final selectedRegionProvider = StateNotifierProvider<SelectedRegionNotifier, String?>((ref) {
  return SelectedRegionNotifier(ref.read(storageServiceProvider));
});

class SelectedRegionNotifier extends StateNotifier<String?> {
  final StorageService _storage;

  SelectedRegionNotifier(this._storage) : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getSelectedRegion();
  }

  Future<void> setRegion(String? regionId) async {
    state = regionId;
    if (regionId != null) {
      await _storage.saveSelectedRegion(regionId);
    }
  }
}

// Selected category provider
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Live rooms provider
final liveRoomsProvider = FutureProvider.family<List<Room>, String?>((ref, regionId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getLiveRooms(regionId: regionId);
  
  if (response['success'] == true) {
    final data = response['data'] as List;
    return data.map((json) => Room.fromJson(json)).toList();
  }
  return [];
});

// Scheduled rooms provider
final scheduledRoomsProvider = FutureProvider.family<List<Room>, String?>((ref, regionId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getScheduledRooms(regionId: regionId);
  
  if (response['success'] == true) {
    final data = response['data'] as List;
    return data.map((json) => Room.fromJson(json)).toList();
  }
  return [];
});

// All rooms with filters
final filteredRoomsProvider = FutureProvider<List<Room>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final regionId = ref.watch(selectedRegionProvider);
  final categoryId = ref.watch(selectedCategoryProvider);
  
  final response = await api.getRooms(
    regionId: regionId,
    categoryId: categoryId,
  );
  
  if (response['success'] == true) {
    final items = response['data']['items'] as List;
    return items.map((json) => Room.fromJson(json)).toList();
  }
  return [];
});

// Room detail provider
final roomDetailProvider = FutureProvider.family<Room?, String>((ref, roomId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getRoom(roomId);
  
  if (response['success'] == true) {
    return Room.fromJson(response['data']);
  }
  return null;
});

// Refresh trigger for rooms
final roomsRefreshProvider = StateProvider<int>((ref) => 0);

void refreshRooms(WidgetRef ref) {
  ref.read(roomsRefreshProvider.notifier).state++;
  ref.invalidate(liveRoomsProvider);
  ref.invalidate(scheduledRoomsProvider);
  ref.invalidate(filteredRoomsProvider);
}
