# flutter_crash_guard

Error handling mixin and Firebase Crashlytics integration. Works with any state management or DI—implement one getter and call `handleError`.

## Features

- **ErrorHandlingMixin**: Add the mixin, implement `ErrorHandlingService get errorHandlingService` (from Riverpod, GetIt, etc.), then call `handleError(operation: '...', error: e, ...)`.
- **ErrorHandlingService**: Wraps Firebase Crashlytics (init, log, recordError, Flutter/platform/zoned error handlers).
- **ErrorSeverity**: low, medium, high, critical (mapped from error type when not overridden).
- Optional **CrashlyticsNavigatorObserver** for route breadcrumbs.
- **Riverpod**: `errorHandlingServiceProvider` and `ref.errorHandlingService` extension for the getter.

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_crash_guard: ^2.0.0
```

Ensure your app has Firebase configured (e.g. `Firebase.initializeApp` and Crashlytics in your project).

## Setup

1. Create and initialize the service, then wire it to your DI and Flutter/platform handlers:

```dart
final errorHandlingService = ErrorHandlingService();
await errorHandlingService.initialize(firebaseOptions, enableInDebugMode: false);
FlutterError.onError = errorHandlingService.handleFlutterError;
PlatformDispatcher.instance.onError = errorHandlingService.handlePlatformError;
// In runZonedGuarded, use errorHandlingService.handleZonedError for the zone callback.

// Riverpod: override the provider in your ProviderContainer:
// errorHandlingServiceProvider.overrideWithValue(errorHandlingService),

// Other DI: register errorHandlingService (GetIt, Provider, Bloc constructor, Get.put, etc.).
```

2. Use the mixin by implementing the `errorHandlingService` getter and calling `handleError` without a ref:

```dart
// Riverpod example
class MyNotifier extends StateNotifier<MyState> with ErrorHandlingMixin {
  MyNotifier(this.ref) : super(MyState.initial());
  final Ref ref;

  @override
  ErrorHandlingService get errorHandlingService => ref.errorHandlingService;

  Future<void> load() async {
    try {
      // ...
    } catch (e, s) {
      handleError(operation: 'load', error: e, stackTrace: s);
    }
  }
}
```

## Other state management

Implement `ErrorHandlingService get errorHandlingService` with your DI and call `handleError(operation: ..., error: e, stackTrace: s)`.

- **Provider**: In a class that has access to `BuildContext`, e.g. store the service in a field from `context.read<ErrorHandlingService>()` in `initState`/`didChangeDependencies`, then `ErrorHandlingService get errorHandlingService => _service;`.
- **GetIt**: `ErrorHandlingService get errorHandlingService => GetIt.I<ErrorHandlingService>();`
- **Bloc**: Inject `ErrorHandlingService` in the bloc constructor; then `ErrorHandlingService get errorHandlingService => _errorHandlingService;`
- **GetX**: `ErrorHandlingService get errorHandlingService => Get.find<ErrorHandlingService>();` (after registering with `Get.put`).

## License

BSD-3-Clause. See LICENSE.
