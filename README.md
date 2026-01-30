# flutter_crash_guard

Riverpod-friendly error handling mixin and Firebase Crashlytics integration with automatic error categorization and severity.

## Features

- **ErrorHandlingMixin**: Use on any class with a Riverpod `Ref`. Call `handleError(ref, operation: '...', error: e, ...)` for unified logging and categorization.
- **ErrorHandlingService**: Wraps Firebase Crashlytics (init, log, recordError, Flutter/platform/zoned error handlers).
- **ErrorSeverity**: low, medium, high, critical (mapped from error type when not overridden).
- Optional **CrashlyticsNavigatorObserver** for route breadcrumbs.

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_crash_guard: ^1.0.0
```

Ensure your app has Firebase configured (e.g. `Firebase.initializeApp` and Crashlytics in your project).

## Setup

1. Create and initialize the service, then override the provider:

```dart
final errorHandlingService = ErrorHandlingService();
await errorHandlingService.initialize(firebaseOptions, enableInDebugMode: false);
FlutterError.onError = errorHandlingService.handleFlutterError;
PlatformDispatcher.instance.onError = errorHandlingService.handlePlatformError;
// In runZonedGuarded, use errorHandlingService.handleZonedError for the zone callback.

// In your ProviderContainer overrides:
errorHandlingServiceProvider.overrideWithValue(errorHandlingService),
```

2. Use the mixin in notifiers or services that have access to `Ref`:

```dart
class MyNotifier extends StateNotifier<MyState> with ErrorHandlingMixin {
  Future<void> load() async {
    try {
      // ...
    } catch (e, s) {
      handleError(ref, operation: 'load', error: e, stackTrace: s);
    }
  }
}
```

## License

BSD-3-Clause. See LICENSE.
