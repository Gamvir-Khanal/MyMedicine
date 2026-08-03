// Basic smoke test: verifies the app boots and shows the home screen.
//
// The original counter-app boilerplate here didn't test anything
// relevant to this app (there's no counter or '+' icon tap flow), and
// it no longer compiled once SmartMedicineCabinetApp started requiring
// a themeProvider.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_medicine_cabinet/main.dart';
import 'package:smart_medicine_cabinet/providers/theme_provider.dart';
import 'package:smart_medicine_cabinet/utils/constants.dart';

void main() {
  testWidgets('App boots and shows the home screen', (tester) async {
    // ThemeProvider reads shared_preferences on load - without this mock
    // setup, that call throws MissingPluginException in a widget test.
    SharedPreferences.setMockInitialValues({});
    final themeProvider = ThemeProvider();
    await themeProvider.loadThemeMode();

    await tester
        .pumpWidget(SmartMedicineCabinetApp(themeProvider: themeProvider));
    await tester.pumpAndSettle();

    // The AppBar title should be visible once the home screen builds.
    expect(find.text(AppConstants.appName), findsOneWidget);
    // The "Add Medicine" FAB should also be present.
    expect(find.text('Add Medicine'), findsOneWidget);
  });
}
