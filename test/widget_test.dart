import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:encryption_test_project/main.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('Encryption UI Test', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify the text field is present
      expect(find.byType(TextField), findsOneWidget);

      // Verify all buttons are present using keys
      expect(find.byKey(const Key('encrypt_button')), findsOneWidget);
      expect(find.byKey(const Key('check_key_button')), findsOneWidget);
      expect(find.byKey(const Key('test_existing_button')), findsOneWidget);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Test Message');
      await tester.pump();

      // Verify text was entered
      expect(find.text('Test Message'), findsOneWidget);

      // Tap the encrypt button using the specific key
      await tester.tap(find.byKey(const Key('encrypt_button')));
      await tester.pumpAndSettle();

      // Verify the original text is shown in the result
      expect(find.textContaining('Original: Test Message'), findsOneWidget);
    });
  });
}
