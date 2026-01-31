import 'package:flutter_crash_guard/flutter_crash_guard.dart';

/// Minimal example: a class using [ErrorHandlingMixin] with the getter-based API.
///
/// Implement [errorHandlingService] with your DI (Riverpod: ref.read(errorHandlingServiceProvider),
/// GetIt: GetIt.I<ErrorHandlingService>(), etc.). Then call [handleError] without a ref.
class ExampleService with ErrorHandlingMixin {
  ExampleService(this._errorHandlingService);

  final ErrorHandlingService _errorHandlingService;

  @override
  ErrorHandlingService get errorHandlingService => _errorHandlingService;

  Future<void> load() async {
    try {
      // Simulate work that might throw.
      throw StateError('Example failure');
    } catch (e, s) {
      handleError(operation: 'load', error: e, stackTrace: s);
    }
  }
}

void main() {
  // Full setup requires Firebase init and DI registration (see README).
  // This demonstrates the API: implement errorHandlingService getter, call handleError(...).
  final service = ErrorHandlingService();
  final example = ExampleService(service);
  example.load();
}
