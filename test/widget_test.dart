import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the authentication screen when signed out', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MoneyTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Register'), findsOneWidget);
  });
}
