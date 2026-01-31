import 'package:flutter_crash_guard/flutter_crash_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorSeverity', () {
    test('has expected values', () {
      expect(ErrorSeverity.values, contains(ErrorSeverity.low));
      expect(ErrorSeverity.values, contains(ErrorSeverity.medium));
      expect(ErrorSeverity.values, contains(ErrorSeverity.high));
      expect(ErrorSeverity.values, contains(ErrorSeverity.critical));
      expect(ErrorSeverity.values.length, 4);
    });
  });

  group('ErrorHandlingMixin', () {
    test('handleError works with getter-based service (no ref)', () {
      final service = ErrorHandlingService();
      final subject = _TestMixinUser(service);

      expect(
        () => subject.handleError(
          operation: 'test',
          error: Exception('test error'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });
  });
}

class _TestMixinUser with ErrorHandlingMixin {
  _TestMixinUser(this._service);

  final ErrorHandlingService _service;

  @override
  ErrorHandlingService get errorHandlingService => _service;
}
