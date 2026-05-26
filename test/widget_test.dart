import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:letters/core/services/storage_service.dart';
import 'package:letters/main.dart';
import 'package:letters/screens/splash/splash_screen.dart';

void main() {
  testWidgets('App boots into splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: 'API_BASE_URL=http://localhost:3000');

    final storage = await StorageService.create();
    await tester.pumpWidget(LettersApp(storage: storage));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Letters'), findsOneWidget);
  });
}
