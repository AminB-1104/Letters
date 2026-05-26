import 'package:go_router/go_router.dart';

import '../core/constants/route_names.dart';
import '../screens/home/home_screen.dart';
import '../screens/splash/splash_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter config = GoRouter(
    initialLocation: RouteNames.splashPath,
    routes: [
      GoRoute(
        path: RouteNames.splashPath,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.homePath,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}
