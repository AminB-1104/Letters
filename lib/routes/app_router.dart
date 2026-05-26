// ignore_for_file: prefer_initializing_formals
// Reason: keep `auth` as the public named param; the private `_auth` field is
// bound via the initializer list to match the pattern used by other services.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/route_names.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../screens/home/home_screen.dart';
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
        builder: (context, state) => const HomeScreen(),
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

    if (onSplash || onAuthRoute) return RouteNames.homePath;
    return null;
  }
}
