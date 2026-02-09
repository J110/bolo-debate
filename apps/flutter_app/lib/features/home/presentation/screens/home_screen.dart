import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/core/services/api_service.dart';
import 'package:bolo_debate/features/home/presentation/providers/data_providers.dart';
import 'package:bolo_debate/shared/widgets/room_card.dart';
import 'package:bolo_debate/shared/widgets/category_chips.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRegion = ref.watch(selectedRegionProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    
    // Create filter params
    final filterParams = RoomFilterParams(
      regionId: selectedRegion,
      categoryId: selectedCategory,
    );
    
    final liveRoomsAsync = ref.watch(liveRoomsProvider(filterParams));
    final scheduledRoomsAsync = ref.watch(scheduledRoomsProvider(filterParams));
    final regionsAsync = ref.watch(regionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bolo Debate',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            regionsAsync.when(
              data: (regions) {
                final region = selectedRegion != null
                    ? regions.where((r) => r.id == selectedRegion).firstOrNull
                    : null;
                return GestureDetector(
                  onTap: () => _showRegionPicker(context, ref, regions),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        region?.name ?? 'All Regions',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(height: 14),
              error: (_, __) => const SizedBox(height: 14),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(liveRoomsProvider(filterParams));
          ref.invalidate(scheduledRoomsProvider(filterParams));
        },
        child: CustomScrollView(
          slivers: [
            // Server waking up indicator
            Consumer(
              builder: (context, ref, child) {
                final isWakingUp = ref.watch(serverWakingUpProvider);
                if (!isWakingUp) return const SliverToBoxAdapter(child: SizedBox.shrink());
                
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Server is waking up...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber[800],
                                ),
                              ),
                              Text(
                                'Free tier servers sleep after inactivity. Please wait ~30 seconds.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Categories
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: CategoryChips(),
              ),
            ),

            // Live Rooms Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live Now',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: See all live rooms
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),
            liveRoomsAsync.when(
              data: (rooms) {
                if (rooms.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: Icons.mic_off,
                      title: 'No live rooms',
                      subtitle: 'Check back soon or start your own debate!',
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(right: index < rooms.length - 1 ? 12 : 0),
                          child: SizedBox(
                            width: 300,
                            child: RoomCard(
                              room: rooms[index],
                              onTap: () => context.push('/room/${rooms[index].id}/detail'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ServerErrorWidget(
                  error: e.toString(),
                  onRetry: () => ref.invalidate(liveRoomsProvider(filterParams)),
                ),
              ),
            ),

            // Scheduled Rooms Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 20, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Text(
                          'Coming Up',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: See all scheduled rooms
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),
            scheduledRoomsAsync.when(
              data: (rooms) {
                if (rooms.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _EmptyState(
                      icon: Icons.event_busy,
                      title: 'No upcoming rooms',
                      subtitle: 'Schedule a room to start a discussion!',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RoomCard(
                            room: rooms[index],
                            onTap: () => context.push('/room/${rooms[index].id}/detail'),
                          ),
                        );
                      },
                      childCount: rooms.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ServerErrorWidget(
                  error: e.toString(),
                  onRetry: () => ref.invalidate(scheduledRoomsProvider(filterParams)),
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegionPicker(BuildContext context, WidgetRef ref, List regions) {
    final selectedRegion = ref.read(selectedRegionProvider);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Region',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // "All Regions" option
              ListTile(
                leading: Icon(
                  Icons.public,
                  color: selectedRegion == null ? AppColors.primary : null,
                ),
                title: Text(
                  'All Regions',
                  style: TextStyle(
                    fontWeight: selectedRegion == null ? FontWeight.bold : FontWeight.normal,
                    color: selectedRegion == null ? AppColors.primary : null,
                  ),
                ),
                subtitle: const Text('Show rooms from all regions'),
                trailing: selectedRegion == null 
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(selectedRegionProvider.notifier).setRegion(null);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    final isSelected = selectedRegion == region.id;
                    return ListTile(
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: isSelected ? AppColors.primary : null,
                      ),
                      title: Text(
                        region.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      subtitle: Text(region.state),
                      trailing: isSelected 
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref.read(selectedRegionProvider.notifier).setRegion(region.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ServerErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ServerErrorWidget({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Check if it's a timeout/connection error
    final isServerSleeping = error.contains('timeout') || 
        error.contains('connection') ||
        error.contains('waking up') ||
        error.contains('Server is starting');
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isServerSleeping 
            ? Colors.amber.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isServerSleeping
              ? Colors.amber.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isServerSleeping ? Icons.cloud_outlined : Icons.error_outline,
            size: 40,
            color: isServerSleeping ? Colors.amber[700] : Colors.red[400],
          ),
          const SizedBox(height: 12),
          Text(
            isServerSleeping 
                ? 'Server is waking up...'
                : 'Something went wrong',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isServerSleeping ? Colors.amber[800] : Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isServerSleeping
                ? 'Free tier servers sleep after inactivity.\nThis usually takes 30-60 seconds.'
                : error,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isServerSleeping ? Colors.amber[700] : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
