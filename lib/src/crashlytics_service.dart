import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final errorHandlingServiceProvider = Provider<ErrorHandlingService>((ref) {
  throw UnimplementedError(
      'errorHandlingServiceProvider must be overridden in main.');
}); //throw UnimplementedError is a placeholder.

class ErrorHandlingService {
  bool _crashlyticsReady = false;
  late FirebaseCrashlytics _crashlytics;

  /// Initializes Firebase and Firebase Crashlytics.
  ///
  /// [firebaseOptions]: The FirebaseOptions for the current platform.
  /// [enableInDebugMode]: Set to true to enable Crashlytics collection even in debug mode.
  Future<void> initialize(FirebaseOptions firebaseOptions,
      {bool enableInDebugMode = false}) async {
    try {
      await Firebase.initializeApp(options: firebaseOptions);
      _crashlytics = FirebaseCrashlytics.instance;

      // Enable/Disable Crashlytics collection based on build mode and explicit preference.
      // In release mode, it's always enabled unless explicitly disabled by user opt-out.
      // In debug mode, it's disabled by default to avoid cluttering the console,
      // but can be enabled for testing.
      final bool collectionEnabled = kReleaseMode || enableInDebugMode;
      await _crashlytics.setCrashlyticsCollectionEnabled(collectionEnabled);

      if (collectionEnabled) {
        // Set app version and build number as custom keys for all reports.
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        await _crashlytics.setCustomKey('app_version', packageInfo.version);
        await _crashlytics.setCustomKey(
            'build_number', packageInfo.buildNumber);
      }

      _crashlyticsReady = true;
      debugPrint(
          'ErrorHandlingService: Firebase Crashlytics initialized. Collection enabled: $collectionEnabled');
    } catch (e, stack) {
      debugPrint(
          'ErrorHandlingService: Firebase Crashlytics initialization failed: $e\n$stack');
    }
  }

  /// Sets a unique user identifier for all subsequent crash reports.
  ///
  /// This helps in tracking issues per user.
  Future<void> setUserIdentifier(String identifier) async {
    if (!_crashlyticsReady) {
      debugPrint(
          'ErrorHandlingService: Crashlytics not ready, cannot set user identifier.');
      return;
    }
    await _crashlytics.setUserIdentifier(identifier);
    await log('User identifier set: $identifier');
  }

  /// Sets a custom key-value pair for upcoming crash reports.
  ///
  /// Only String, bool, and num values are directly supported by Crashlytics.
  /// Other object types will be converted to String.
  Future<void> setCustomKey(String key, Object value) async {
    if (!_crashlyticsReady) {
      debugPrint(
          'ErrorHandlingService: Crashlytics not ready, cannot set custom key "$key".');
      return;
    }
    if (value is String || value is bool || value is num) {
      await _crashlytics.setCustomKey(key, value);
    } else {
      await _crashlytics.setCustomKey(key, value.toString());
      debugPrint(
          'ErrorHandlingService: Custom key "$key" value was converted to String.');
    }
  }

  /// Adds a log message (breadcrumb) to upcoming crash reports.
  ///
  /// These logs provide context leading up to a crash or error.
  Future<void> log(String message) async {
    if (!_crashlyticsReady) {
      debugPrint(
          'ErrorHandlingService: Crashlytics not ready, cannot log message: "$message".');
      return;
    }
    await _crashlytics.log(message);
  }

  /// Handles errors caught by Flutter's framework-level error handler (`FlutterError.onError`).
  ///
  /// Dumps the error to console and records it with Crashlytics, classifying it as
  /// fatal or non-fatal based on internal patterns.
  void handleFlutterError(FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(
        details); // Always dump to console for debugging

    log('FlutterError caught: ${details.exceptionAsString()}');

    if (!_crashlyticsReady) {
      debugPrint(
          'ErrorHandlingService: Flutter error occurred before Crashlytics was ready. Details: ${details.exception}');
      return;
    }

    final isFatal = _shouldTreatAsFatal(
        details.exception, details.stack); // Use the general classifier
    setCustomKey('error_type', 'FlutterError');
    setCustomKey('fatal_classification', isFatal ? 'Fatal' : 'Non-Fatal');
    setCustomKey('flutter_error_library', details.library ?? 'unknown');
    setCustomKey(
        'flutter_error_context', details.context?.toString() ?? 'unknown');
    setCustomKey('flutter_error_silent',
        details.silent); // Useful if Flutter silently handled it

    // recordFlutterFatalError and recordFlutterError are specific APIs for FlutterErrorDetails
    if (isFatal) {
      _crashlytics.recordFlutterFatalError(details);
    } else {
      _crashlytics.recordFlutterError(details, fatal: false);
    }
  }

  /// Handles errors caught by the platform dispatcher (`PlatformDispatcher.instance.onError`).
  ///
  /// These are typically errors originating outside the Flutter framework, such as from isolates.
  /// Records the error with Crashlytics, classifying it.
  /// Returns true to indicate the error has been handled and prevent default platform termination.
  bool handlePlatformError(Object error, StackTrace stack) {
    final errorMessage = error.toString().toLowerCase();
    log('PlatformError caught: $errorMessage');
    debugPrint('ErrorHandlingService: Platform error caught: $error');

    if (!_crashlyticsReady) {
      debugPrint(
          'ErrorHandlingService: Platform error occurred before Crashlytics was ready.');
      return true; // Still return true to prevent app termination by OS
    }

    final isFatal =
        _shouldTreatAsFatal(error, stack); // Apply classification here
    setCustomKey('error_type', 'PlatformError');
    setCustomKey('fatal_classification', isFatal ? 'Fatal' : 'Non-Fatal');

    _crashlytics.recordError(error, stack,
        fatal: isFatal, // Use the classified fatal status
        reason: 'PlatformDispatcher.onError',
        information: ['Platform error message: $errorMessage']);
    return true; // Important: Always return true to signal the error has been handled.
  }

  /// Handles errors caught by `runZonedGuarded`.
  ///
  /// This is the ultimate catch-all for errors in asynchronous operations.
  /// Records the error with Crashlytics, classifying it.
  void handleZonedError(Object error, StackTrace stack) {
    log('ZonedError caught: ${error.toString()}');
    debugPrint('ErrorHandlingService: Zoned error caught: $error');

    if (!_crashlyticsReady) {
      debugPrint(
          'ErrorHandlingService: Zoned error occurred before Crashlytics was ready.');
      return;
    }

    try {
      final isFatal =
          _shouldTreatAsFatal(error, stack); // Apply classification here
      setCustomKey('error_type', 'ZonedError');
      setCustomKey('fatal_classification', isFatal ? 'Fatal' : 'Non-Fatal');
      setCustomKey('zoned_error_runtime_type', error.runtimeType.toString());
      _crashlytics.recordError(error, stack,
          fatal: isFatal,
          reason: 'runZonedGuarded'); // Use classified fatal status
    } catch (e, s) {
      debugPrint(
          'ErrorHandlingService: Failed to record zoned error in Crashlytics: $error');
      debugPrint('ErrorHandlingService: Crashlytics recording failure: $e\n$s');
    }
  }

  /// Manually records an error to Firebase Crashlytics.
  ///
  /// Use this for specific caught exceptions where you want to explicitly control
  /// whether it's reported as fatal and provide additional context.
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
    Iterable<Object> information = const [],
  }) async {
    log('GenericError recorded: ${exception.toString()} - Reason: $reason - Fatal: $fatal');
    if (!_crashlyticsReady) {
      debugPrint(
          'ErrorHandlingService: Tried to record error before Crashlytics ready: $exception');
      return;
    }
    setCustomKey('error_type', 'ManualRecord');
    setCustomKey('fatal_classification', fatal ? 'Fatal' : 'Non-Fatal');
    if (reason != null) {
      setCustomKey('record_reason', reason);
    }

    await _crashlytics.recordError(exception, stack,
        fatal: fatal, reason: reason, information: information);
  }

  /// Determines if an error should be treated as fatal based on its exception and stack trace.
  ///
  /// This method contains patterns to classify common Flutter and Dart errors.
  bool _shouldTreatAsFatal(Object exception, StackTrace? stack) {
    final exceptionString = exception.toString().toLowerCase();
    final stackString = stack?.toString().toLowerCase() ?? '';

    // Explicitly Fatal Patterns: Indicate severe, unrecoverable application state.
    final fatalPatterns = [
      'assertion failed',
      'null check operator used on a null value',
      'nullpointerexception',
      'nosuchmethoderror',
      'typeerror',
      'rangeerror',
      'argumenterror',
      'stateerror',
      'unsupportederror',
      'concurrent modification',
      'out of memory',
      'outofmemoryerror',
      'failed to allocate',
      'deadsystemexception',
      'system died',
      'bad state',
      'cast error',
      'stackoverflowerror',
      'cyclic initialization',

      'runtimeexception',
      'illegalargumentexception',
      'illegalstateexception',
      'arrayindexoutofboundsexception',
      'indexoutofboundsexception',

      'signal sigabrt',
      'signal sigsegv',
      'fatal error',
      'unrecognized selector sent to instance',

      'binding has not yet been initialized',
    ];

    for (final pattern in fatalPatterns) {
      if (exceptionString.contains(pattern)) return true;
    }

    // Non-fatal Patterns: Indicate issues that typically don't crash the entire app
    // or are recoverable/expected in certain scenarios (e.g., network, UI glitches).
    final nonFatalPatterns = [
      // Image loading errors (often handled by errorWidget in UI)
      'image codec',
      'networkimageloadexception',
      'resolving an image codec',
      'failed to load network image',
      // Common Network errors (often recoverable or UI can handle)
      'clientexception',
      'socketexception',
      'connection closed',
      'connection reset',
      'connection timeout',
      'connection failed',
      'handshake exception',
      'certificate verify failed',
      'httpsexception',
      'host lookup failed',
      'no internet connection',
      'dioexception',
      // Catch the DioException type itself
      'software caused connection abort',
      // Specific message from your crash
      'timeout',
      // General timeout exception
      // UI related (often don't crash the whole app, but indicate bugs)
      'renderbox was not laid out',
      'renderflex overflowed',
      'viewport was given unbounded height',
      'a renderwidget was told to layout',
      // Platform channel errors (can sometimes be non-fatal if feature is optional)
      'platformexception',
      'missingpluginexception',
      // Data parsing/file access errors (can be non-fatal if data/file is optional)
      'formatexception',
      // e.g., bad JSON from a non-critical API
      'pathexception',
      // e.g., trying to access an optional cache file
    ];

    for (final pattern in nonFatalPatterns) {
      if (exceptionString.contains(pattern)) return false;
    }

    // Non-fatal Stack Patterns: Look for specific framework stack traces
    // that are commonly associated with non-fatal issues.
    final nonFatalStackPatterns = [
      'imagestream',
      'image_stream',
      'network_image',
      'cached_network_image',
      '_loadasync',
      'imagecodec',
      'decodeimagefromlist',
      'render_object.dart', // Many rendering errors originate here
    ];

    for (final pattern in nonFatalStackPatterns) {
      if (stackString.contains(pattern)) return false;
    }

    // Context-based decisions: Check the context string from FlutterErrorDetails
    // (if available) for common non-fatal scenarios.
    // Note: This 'context' check is primarily for FlutterErrorDetails.
    // For raw Objects/StackTraces, this part might not apply directly
    // unless you extract context from the stack trace itself.
    if (exception is FlutterErrorDetails) {
      final context = exception.context?.toString().toLowerCase() ?? '';
      if (context.contains('during build') ||
          context.contains('building widget') ||
          context.contains('laying out') ||
          context.contains('painting') ||
          context.contains('compositing') ||
          context.contains('widget') ||
          context.contains('render') ||
          context.contains('hot reload')) {
        // Filter out hot reload noise
        return false;
      }
    }

    // Default to fatal for anything not explicitly classified as non-fatal.
    // This ensures that unknown or truly critical issues are always highlighted.
    return true;
  }
}
