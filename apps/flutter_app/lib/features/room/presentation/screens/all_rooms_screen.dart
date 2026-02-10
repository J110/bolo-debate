import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/home/presentation/providers/data_providers.dart';
import 'package:bolo_debate/shared/widgets/room_card.dart';

class AllRoomsScreen extends ConsumerWidget {
  const AllRoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterParams = RoomFilterParams();
    final liveRoomsAsync = ref.watch(liveRoomsProvider(filterParams));
    final scheduledRoomsAsync = ref.watch(scheduledRoomsProvider(filterParams));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('All Rooms'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.circle, size: 8, color: AppColors.error),
                text: 'Live Now',
              ),
              Tab(
                icon: Icon(Icons.schedule, size: 16),
                text: 'Upcoming',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Live Rooms Tab
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(liveRoomsProvider(filterParams));
              },
              child: liveRoomsAsync.when(
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return _EmptyState(
                      icon: Icons.mic_off,
                      title: 'No live rooms',
                      subtitle: 'Check back soon or start your own debate!',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: RoomCard(
                          room: rooms[index],
                          onTap: () => context.push('/room/${rooms[index].id}/detail'),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(liveRoomsProvider(filterParams)),
                ),
              ),
            ),
            // Scheduled Rooms Tab
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(scheduledRoomsProvider(filterParams));
              },
              child: scheduledRoomsAsync.when(
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return _EmptyState(
                      icon: Icons.event_busy,
                      title: 'No upcoming rooms',
                      subtitle: 'Be the first to schedule a debate!',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: RoomCard(
                          room: rooms[index],
                          onTap: () => context.push('/room/${rooms[index].id}/detail'),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(scheduledRoomsProvider(filterParams)),
                ),
              ),
            ),
          ],
        ),
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
