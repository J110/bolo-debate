import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/home/presentation/providers/data_providers.dart';
import 'package:bolo_debate/shared/widgets/room_card.dart';
import 'package:bolo_debate/shared/widgets/category_chips.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRegion = ref.watch(selectedRegionProvider);
    final liveRoomsAsync = ref.watch(liveRoomsProvider(selectedRegion));
    final scheduledRoomsAsync = ref.watch(scheduledRoomsProvider(selectedRegion));
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
                        region?.name ?? 'Select region',
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
          ref.invalidate(liveRoomsProvider(selectedRegion));
          ref.invalidate(scheduledRoomsProvider(selectedRegion));
        },
        child: CustomScrollView(
          slivers: [
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
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $e')),
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
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Error: $e')),
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
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
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(region.name),
                      subtitle: Text(region.state),
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
