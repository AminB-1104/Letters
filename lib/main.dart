import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/services/api_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/services/auth_service.dart';
import 'providers/app_settings_provider.dart';
import 'providers/user_provider.dart';
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
  late final AuthProvider _authProvider;
  late final AppSettingsProvider _settingsProvider;
  late final UserProvider _userProvider;
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    _api = ApiService(storage: widget.storage);
    _authService = AuthService(_api);
    _authProvider = AuthProvider(
      storage: widget.storage,
      authService: _authService,
    );
    _settingsProvider = AppSettingsProvider(storage: widget.storage);
    _userProvider = UserProvider();
    _router = AppRouter(auth: _authProvider);
  }

  @override
  void dispose() {
    _authProvider.dispose();
    _settingsProvider.dispose();
    _userProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: widget.storage),
        Provider<ApiService>.value(value: _api),
        Provider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<AppSettingsProvider>.value(
          value: _settingsProvider,
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<UserProvider>.value(value: _userProvider),
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
