import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/services/api_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final storage = await StorageService.create();
  runApp(LettersApp(storage: storage));
}

class LettersApp extends StatelessWidget {
  const LettersApp({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<ApiService>(
          create: (_) => ApiService(storage: storage),
        ),
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) => AppSettingsProvider(storage: storage),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(storage: storage),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp.router(
            title: 'Letters',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            routerConfig: AppRouter.config,
          );
        },
      ),
    );
  }
}
