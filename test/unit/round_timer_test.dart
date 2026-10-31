import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_buzzer/features/game/domain/round_timer.dart';

void main() {
  group('RoundTimer', () {
    test('timer fires onTimeout when duration expires', () async {
      bool fired = false;
      final timer = RoundTimer.start(
        duration: const Duration(milliseconds: 150),
        onTimeout: () => fired = true,
        attemptId: 'test-attempt',
      );

      expect(timer.isActive, isTrue);
      expect(timer.hasFired, isFalse);
      expect(timer.attemptId, 'test-attempt');

      await Future.delayed(const Duration(milliseconds: 300));

      expect(fired, isTrue);
      expect(timer.isActive, isFalse);
      expect(timer.hasFired, isTrue);
      expect(timer.remaining, Duration.zero);
    });

    test('timer can be canceled early without firing callback', () async {
      bool fired = false;
      final timer = RoundTimer.start(
        duration: const Duration(milliseconds: 300),
        onTimeout: () => fired = true,
        attemptId: 'cancel-attempt',
      );

      expect(timer.isActive, isTrue);
      timer.cancel();

      expect(timer.isActive, isFalse);
      expect(timer.hasFired, isFalse);

      await Future.delayed(const Duration(milliseconds: 350));
      expect(fired, isFalse);
    });

    test('cancel after timeout is safe no-op', () async {
      int fireCount = 0;
      final timer = RoundTimer.start(
        duration: const Duration(milliseconds: 100),
        onTimeout: () => fireCount++,
        attemptId: 'noop-attempt',
      );

      await Future.delayed(const Duration(milliseconds: 250));
      expect(fireCount, 1);

      // Safe no-op
      timer.cancel();
      expect(fireCount, 1);
    });

    test('secondsStream emits countdown values', () async {
      final timer = RoundTimer.start(
        duration: const Duration(milliseconds: 250),
        onTimeout: () {},
        attemptId: 'stream-attempt',
      );

      final values = <int>[];
      final sub = timer.secondsStream.listen(values.add);

      await Future.delayed(const Duration(milliseconds: 350));
      await sub.cancel();

      expect(values, isNotEmpty);
      expect(values.first, greaterThanOrEqualTo(0));
    });
  });
}
