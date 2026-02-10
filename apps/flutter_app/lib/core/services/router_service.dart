import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bolo_debate/features/auth/presentation/providers/auth_provider.dart';
import 'package:bolo_debate/features/auth/presentation/screens/login_screen.dart';
import 'package:bolo_debate/features/auth/presentation/screens/register_screen.dart';
import 'package:bolo_debate/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:bolo_debate/features/home/presentation/screens/home_screen.dart';
import 'package:bolo_debate/features/home/presentation/screens/main_shell.dart';
import 'package:bolo_debate/features/room/presentation/screens/room_screen.dart';
import 'package:bolo_debate/features/room/presentation/screens/create_room_screen.dart';
import 'package:bolo_debate/features/room/presentation/screens/room_detail_screen.dart';
import 'package:bolo_debate/features/room/presentation/screens/all_rooms_screen.dart';
import 'package:bolo_debate/features/profile/presentation/screens/profile_screen.dart';
import 'package:bolo_debate/features/profile/presentation/screens/settings_screen.dart';
import 'package:bolo_debate/features/friends/presentation/screens/friends_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/auth/onboarding',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isLoading = authState.isLoading;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      // While loading auth state, stay on auth routes or redirect to onboarding
      if (isLoading) {
        if (!isAuthRoute) {
          return '/auth/onboarding';
        }
        return null;
      }

      // Redirect to onboarding if not logged in and not on auth route
      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/onboarding';
      }

      // Redirect to home if logged in and on auth route
      if (isLoggedIn && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/auth/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/discover',
            name: 'discover',
            builder: (context, state) => const Placeholder(child: Text('Discover')),
          ),
          GoRoute(
            path: '/friends',
            name: 'friends',
            builder: (context, state) => const FriendsScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Room routes (outside shell for full screen)
      GoRoute(
        path: '/room/:id',
        name: 'room',
        builder: (context, state) {
          final roomId = state.pathParameters['id']!;
          final selectedSide = state.extra as String?;
          return RoomScreen(roomId: roomId, selectedSide: selectedSide);
        },
      ),
      GoRoute(
        path: '/room/:id/detail',
        name: 'roomDetail',
        builder: (context, state) {
          final roomId = state.pathParameters['id']!;
          return RoomDetailScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/create-room',
        name: 'createRoom',
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: '/all-rooms',
        name: 'allRooms',
        builder: (context, state) => const AllRoomsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

class Placeholder extends StatelessWidget {
  final Widget child;
  const Placeholder({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: child),
      body: Center(child: child),
    );
  }
}
