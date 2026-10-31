import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_buzzer/app/app.dart';

void main() {
  testWidgets('QuizBuzzerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QuizBuzzerApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(QuizBuzzerApp), findsOneWidget);
  });
}
