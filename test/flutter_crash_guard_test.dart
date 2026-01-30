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
}
