import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/services/api_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/services/auth_service.dart';
import 'features/social/providers/friend_provider.dart';
import 'features/social/providers/social_provider.dart';
import 'features/social/providers/user_provider.dart';
import 'features/social/services/friend_service.dart';
import 'features/social/services/user_service.dart';
import 'providers/app_settings_provider.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final storage = await StorageService.create();
  runApp(LettersApp(storage: storage));
}

class LettersApp extends StatefulWidget {
  const LettersApp({super.key, required this.storage});

  final StorageService storage;

  @override
  State<LettersApp> createState() => _LettersAppState();
}

class _LettersAppState extends State<LettersApp> {
  late final ApiService _api;
  late final AuthService _authService;
  late final UserService _userService;
  late final FriendService _friendService;
  late final AuthProvider _authProvider;
  late final AppSettingsProvider _settingsProvider;
  late final UserProvider _userProvider;
  late final FriendProvider _friendProvider;
  late final SocialProvider _socialProvider;
  late final AppRouter _router;

  AuthStatus _lastAuthStatus = AuthStatus.unknown;

  @override
  void initState() {
    super.initState();
    _api = ApiService(storage: widget.storage);
    _authService = AuthService(_api);
    _userService = UserService(_api);
    _friendService = FriendService(_api);
    _authProvider = AuthProvider(
      storage: widget.storage,
      authService: _authService,
    );
    _settingsProvider = AppSettingsProvider(storage: widget.storage);
    _userProvider = UserProvider(userService: _userService);
    _friendProvider = FriendProvider(friendService: _friendService);
    _socialProvider = SocialProvider(friendProvider: _friendProvider);
    _router = AppRouter(auth: _authProvider);

    _lastAuthStatus = _authProvider.status;
    _authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final next = _authProvider.status;
    if (next == _lastAuthStatus) return;
    if (_lastAuthStatus == AuthStatus.authenticated &&
        next == AuthStatus.unauthenticated) {
      _userProvider.reset();
      _friendProvider.reset();
      _socialProvider.reset();
    }
    _lastAuthStatus = next;
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _socialProvider.dispose();
    _friendProvider.dispose();
    _userProvider.dispose();
    _authProvider.dispose();
    _settingsProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: widget.storage),
        Provider<ApiService>.value(value: _api),
        Provider<AuthService>.value(value: _authService),
        Provider<UserService>.value(value: _userService),
        Provider<FriendService>.value(value: _friendService),
        ChangeNotifierProvider<AppSettingsProvider>.value(
          value: _settingsProvider,
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<FriendProvider>.value(value: _friendProvider),
        ChangeNotifierProvider<UserProvider>.value(value: _userProvider),
        ChangeNotifierProvider<SocialProvider>.value(value: _socialProvider),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp.router(
            title: 'Letters',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            routerConfig: _router.config,
          );
        },
      ),
    );
  }
}
