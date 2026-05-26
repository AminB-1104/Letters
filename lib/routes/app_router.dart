// ignore_for_file: prefer_initializing_formals
// Reason: keep `auth` as the public named param; the private `_auth` field is
// bound via the initializer list to match the pattern used by other services.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/route_names.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/social/screens/friend_requests_screen.dart';
import '../features/social/screens/friends_list_screen.dart';
import '../features/social/screens/search_users_screen.dart';
import '../features/social/screens/user_profile_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/splash/splash_screen.dart';

class AppRouter {
  AppRouter({required AuthProvider auth}) : _auth = auth;

  final AuthProvider _auth;

  late final GoRouter config = GoRouter(
    initialLocation: RouteNames.splashPath,
    refreshListenable: _auth,
    redirect: _redirect,
    routes: [
      GoRoute(
        path: RouteNames.splashPath,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.signupPath,
        name: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RouteNames.homePath,
        name: RouteNames.home,
        redirect: (_, _) => RouteNames.searchPath,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.searchPath,
              name: RouteNames.search,
              builder: (_, _) => const SearchUsersScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.friendsPath,
              name: RouteNames.friends,
              builder: (_, _) => const FriendsListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.requestsPath,
              name: RouteNames.requests,
              builder: (_, _) => const FriendRequestsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: RouteNames.userProfilePath,
        name: RouteNames.userProfile,
        builder: (context, state) => UserProfileScreen(
          username: state.pathParameters['username']!,
        ),
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final status = _auth.status;
    final location = state.matchedLocation;

    if (status == AuthStatus.unknown) {
      return location == RouteNames.splashPath ? null : RouteNames.splashPath;
    }

    final onAuthRoute = location == RouteNames.loginPath ||
        location == RouteNames.signupPath;
    final onSplash = location == RouteNames.splashPath;

    if (status == AuthStatus.unauthenticated) {
      if (onAuthRoute) return null;
      return RouteNames.loginPath;
    }

    // Authenticated: send users away from auth/splash screens to the default
    // home branch. Any /home* or /u/* path is allowed to render normally.
    if (onSplash || onAuthRoute) return RouteNames.searchPath;
    return null;
  }
}
