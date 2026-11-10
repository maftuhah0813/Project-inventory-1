import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maftuhah_mobile/app.dart';
import 'package:maftuhah_mobile/core/constants/app_strings.dart';

void main() {
  testWidgets('App smoke test renders SplashScreen title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaftuhahApp(),
      ),
    );

    // Verify App Name is rendered on SplashScreen
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.appTagline), findsOneWidget);

    // Pump frames to advance past timer and settle on LoginScreen
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    // Verify that LoginScreen is rendered
    expect(find.text(AppStrings.emailLabel), findsOneWidget);
  });
}
