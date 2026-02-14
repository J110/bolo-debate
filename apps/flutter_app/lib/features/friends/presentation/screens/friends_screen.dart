import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bolo_debate/core/services/api_service.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/shared/models/user_model.dart';
import 'package:bolo_debate/shared/widgets/page_header.dart';

// Friends provider
final friendsProvider = FutureProvider<List<User>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getFriends();
  
  if (response['success'] == true) {
    final data = response['data'] as List;
    return data.map((json) => User.fromJson(json)).toList();
  }
  return [];
});

// Friend requests provider
final friendRequestsProvider = FutureProvider<Map<String, List<dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getFriendRequests();
  
  if (response['success'] == true) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final incoming = List<dynamic>.from(data['incoming'] ?? []);
      final outgoing = List<dynamic>.from(data['outgoing'] ?? []);
      return {'incoming': incoming, 'outgoing': outgoing};
    }
  }
  return {'incoming': [], 'outgoing': []};
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header banner (replaces AppBar)
          PageHeaders.friends(
            onBack: () => Navigator.of(context).pop(),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add, color: Colors.white),
                onPressed: () => _showAddFriendDialog(),
              ),
            ],
          ),
          
          // Tab bar
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Friends'),
                Tab(text: 'Requests'),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FriendsTab(),
                _RequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Enter username',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _usernameController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = _usernameController.text.trim();
              if (username.isNotEmpty) {
                try {
                  final api = ref.read(apiServiceProvider);
                  await api.sendFriendRequest(username);
                  ref.invalidate(friendRequestsProvider);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request sent!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
              _usernameController.clear();
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                const Text('Add friends to see them here'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return _FriendTile(user: friend);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(friendRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        final incoming = requests['incoming'] ?? [];
        final outgoing = requests['outgoing'] ?? [];

        if (incoming.isEmpty && outgoing.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        return ListView(
          children: [
            if (incoming.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Incoming Requests',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ...incoming.map((req) => _RequestTile(
                    request: req,
                    isIncoming: true,
                  )),
            ],
            if (outgoing.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Sent Requests',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ...outgoing.map((req) => _RequestTile(
                    request: req,
                    isIncoming: false,
                  )),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final User user;

  const _FriendTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.2),
        child: Text(
          user.displayName[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(user.displayName),
      subtitle: Text('@${user.username}'),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'invite',
            child: Text('Invite to room'),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove friend'),
          ),
        ],
        onSelected: (value) {
          // TODO: Handle action
        },
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final dynamic request;
  final bool isIncoming;

  const _RequestTile({required this.request, required this.isIncoming});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = request['displayName'] as String;
    final username = request['username'] as String;
    final requestId = request['requestId'] as String;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.2),
        child: Text(
          displayName[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(displayName),
      subtitle: Text('@$username'),
      trailing: isIncoming
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: AppColors.success),
                  onPressed: () async {
                    final api = ref.read(apiServiceProvider);
                    await api.acceptFriendRequest(requestId);
                    ref.invalidate(friendsProvider);
                    ref.invalidate(friendRequestsProvider);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.error),
                  onPressed: () async {
                    final api = ref.read(apiServiceProvider);
                    await api.rejectFriendRequest(requestId);
                    ref.invalidate(friendRequestsProvider);
                  },
                ),
              ],
            )
          : const Text('Pending', style: TextStyle(color: Colors.grey)),
    );
  }
}
