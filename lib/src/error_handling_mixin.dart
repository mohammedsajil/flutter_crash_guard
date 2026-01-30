import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_crash_guard/src/crashlytics_service.dart';

enum ErrorSeverity {
  /// Low severity - User actions, cancellations, not found errors
  /// These errors typically don't require immediate attention
  low,

  /// Medium severity - Network issues, client errors, timeouts
  /// These errors may affect user experience but are usually recoverable
  medium,

  /// High severity - Data parsing, server errors, permission issues
  /// These errors often indicate serious problems that need investigation
  high,

  /// Critical severity - Logic errors, unexpected errors, security issues
  /// These errors are the most serious and require immediate attention
  critical,
}

mixin ErrorHandlingMixin {
  /// Gets the crashlytics service from the ref
  ///
  /// This service provides crash reporting and error tracking.
  /// It's the most reliable and fastest logging option for production.
  ErrorHandlingService getCrashlytics(Ref ref) {
    return ref.read(errorHandlingServiceProvider);
  }

  /// Non-blocking error logging
  ///
  /// This method initiates error logging without blocking the main thread.
  /// It uses a fire-and-forget approach to ensure optimal performance.
  void _logErrorAsync(
    Ref ref, {
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    String? endpoint,
    Map<String, dynamic>? additionalContext,
    String? reason,
    ErrorSeverity? severity,
  }) {
    final crashlytics = getCrashlytics(ref);

    // Build information array with key details
    final information = <String>[
      'Operation: $operation',
      if (endpoint != null) 'Endpoint: $endpoint',
      if (severity != null) 'Severity: ${severity.name.toUpperCase()}',
      if (additionalContext != null)
        ...additionalContext.entries
            .map((e) => '${e.key}: ${e.value}')
            .take(5), // Limit to 5 context items for performance
    ];

    // Fire and forget - direct Crashlytics logging with error handling
    unawaited(crashlytics
        .recordError(
      error,
      stackTrace ?? StackTrace.current,
      fatal: severity == ErrorSeverity.critical,
      reason: reason ?? 'Error in $operation',
      information: information,
    )
        .catchError((e) {
      // Silently fail - don't let logging errors affect the app
      if (kDebugMode) {
        print('ErrorHandlingMixin: Failed to log to Crashlytics: $e');
      }
    }));
  }

  /// Better error categorization with comprehensive type checking
  ///
  /// This method categorizes errors based on their actual type with comprehensive
  /// coverage of Dart runtime errors and network exceptions.
  String _categorizeByType(dynamic error) {
    // Check by type first - most reliable
    final logicError = _isLogicError(error);
    if (logicError != null) return logicError;

    final parsingError = _isParsingError(error);
    if (parsingError != null) return parsingError;

    final networkError = _isNetworkError(error);
    if (networkError != null) return networkError;

    final platformError = _isPlatformError(error);
    if (platformError != null) return platformError;

    final fileError = _isFileError(error);
    if (fileError != null) return fileError;

    // String fallback for specific error patterns
    final stringPatternError = _checkStringPatterns(error);
    if (stringPatternError != null) return stringPatternError;

    return 'UNEXPECTED';
  }

  /// Checks if the error is a logic error (type-based)
  String? _isLogicError(dynamic error) {
    if (error is TypeError ||
        error is StateError ||
        error is AssertionError ||
        error is ArgumentError ||
        error is NoSuchMethodError ||
        error is RangeError) {
      return 'LOGIC_ERROR';
    }
    return null;
  }

  /// Checks if the error is a parsing error (type-based)
  String? _isParsingError(dynamic error) {
    if (error is FormatException ||
        error is JsonUnsupportedObjectError ||
        error is JsonCyclicError) {
      return 'PARSING';
    }
    return null;
  }

  /// Checks if the error is a network-related error
  String? _isNetworkError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'TIMEOUT';
        case DioExceptionType.connectionError:
          return 'NETWORK';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          if (statusCode >= 500) return 'SERVER_ERROR';
          if (statusCode == 401) return 'AUTHENTICATION';
          if (statusCode == 403) return 'AUTHORIZATION';
          if (statusCode >= 400 && statusCode < 500) return 'CLIENT_ERROR';
          return 'API_ERROR';
        case DioExceptionType.cancel:
          return 'USER_CANCELLED';
        default:
          return 'NETWORK';
      }
    }

    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return 'NETWORK';
    }

    return null;
  }

  /// Checks if the error is a platform-specific error
  String? _isPlatformError(dynamic error) {
    if (error is PlatformException || error is MissingPluginException) {
      return 'PLATFORM_ERROR';
    }
    return null;
  }

  /// Checks if the error is a file system error
  String? _isFileError(dynamic error) {
    if (error is FileSystemException || error is IOException) {
      return 'FILE_ERROR';
    }
    return null;
  }

  /// Checks error patterns in string representation
  String? _checkStringPatterns(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Logic errors
    if (errorStr.contains('null check operator used on a null value') ||
        errorStr.contains("type 'null' is not a subtype")) {
      return 'LOGIC_ERROR';
    }

    // Permission and security errors
    if (errorStr.contains('permission') || errorStr.contains('unauthorized')) {
      return 'PERMISSION';
    }
    if (errorStr.contains('security') || errorStr.contains('forbidden')) {
      return 'SECURITY';
    }

    // Database errors
    if (errorStr.contains('database') || errorStr.contains('sqlite')) {
      return 'DATABASE_ERROR';
    }

    return null;
  }

  /// Map error to severity automatically
  ///
  /// This method automatically maps error categories to severity levels.
  /// Severity levels determine how the error should be handled and reported.
  ///
  /// Severity Mapping:
  /// - CRITICAL: Unexpected errors, logic errors, security issues
  /// - HIGH: Data parsing errors, server errors, permission issues
  /// - MEDIUM: Network issues, client errors, authentication/authorization errors
  /// - LOW: User cancellations, not found errors
  ErrorSeverity _mapErrorToSeverity(dynamic error) {
    final category = _categorizeByType(error);
    switch (category) {
      case 'UNEXPECTED':
      case 'LOGIC_ERROR':
      case 'SECURITY':
        return ErrorSeverity.critical;
      case 'PARSING':
      case 'SERVER_ERROR':
      case 'PERMISSION':
      case 'DATABASE_ERROR':
      case 'FILE_ERROR':
        return ErrorSeverity.high;
      case 'TIMEOUT':
      case 'NETWORK':
      case 'API_ERROR':
      case 'CLIENT_ERROR':
      case 'AUTHENTICATION':
      case 'AUTHORIZATION':
      case 'PLATFORM_ERROR':
        return ErrorSeverity.medium;
      case 'USER_CANCELLED':
        return ErrorSeverity.low;
      default:
        return ErrorSeverity.medium;
    }
  }

  /// Unified error handling method that automatically detects error type and context
  ///
  /// This is the PRIMARY method for error handling in the application.
  /// It automatically detects error types (DioException vs generic errors) and applies
  /// appropriate context and categorization.
  ///
  /// Key Features:
  /// - Automatic error type detection (DioException vs generic)
  /// - Automatic context enrichment based on error type
  /// - Automatic error categorization and severity assignment
  /// - Robust error handling with fallback mechanisms
  /// - Non-blocking logging for optimal performance
  /// - Support for parsing errors with raw data context
  /// - Support for network errors with endpoint context
  ///
  /// Use this method for ALL error handling - it replaces handleParsingError and handleNetworkError.
  ///
  /// Parameters:
  /// - [operation]: The operation that failed (e.g. 'load_user_data')
  /// - [error]: The error object (can be DioException or any other error)
  /// - [stackTrace]: The stack trace associated with the error
  /// - [endpoint]: The API endpoint that failed (optional, auto-detected for DioExceptions)
  /// - [additionalContext]: Additional context information (optional)
  /// - [severity]: Override the automatic severity assignment (optional)
  /// - [dataType]: The type of data being processed (for parsing errors)
  /// - [rawData]: Raw data that failed to parse (for parsing errors)
  void handleError(
    Ref ref, {
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    String? endpoint,
    Map<String, dynamic>? additionalContext,
    ErrorSeverity? severity,
    String? dataType,
    Map<String, dynamic>? rawData,
  }) {
    try {
      // Build enriched context with both error_type and error_category
      final enrichedContext = <String, dynamic>{
        'operation': operation,
        'timestamp': DateTime.now().toIso8601String(),
        'error_type': error.runtimeType.toString(),
        'error_category': _categorizeByType(error),
        if (error is DioException) 'dio_type': error.type.name,
        if (error is DioException) 'status_code': error.response?.statusCode,
        if (endpoint != null) 'endpoint': endpoint,
        if (dataType != null) 'dataType': dataType,
        if (rawData != null) ...{
          'rawDataSample': _getRawDataPreview(rawData),
          'rawDataSize': rawData.toString().length,
        },
        ...?additionalContext,
      };

      // Auto-detect endpoint for DioExceptions if not provided
      if (error is DioException && endpoint == null) {
        enrichedContext['endpoint'] = error.requestOptions.uri.toString();
      }

      // Determine severity automatically if not provided
      final finalSeverity = severity ?? _mapErrorToSeverity(error);

      // Create appropriate reason based on error type
      String reason;
      if (dataType != null) {
        reason = 'Parsing Error: $dataType';
      } else if (error is DioException) {
        reason = 'Network Error: $operation';
      } else {
        reason = 'Error in $operation';
      }

      // Log the error with unified context
      _logErrorAsync(
        ref,
        operation: operation,
        error: error,
        stackTrace: stackTrace,
        endpoint: endpoint,
        additionalContext: enrichedContext,
        reason: reason,
        severity: finalSeverity,
      );
    } catch (e) {
      // Fallback error handling - don't let error handling itself cause crashes
      if (kDebugMode) {
        print('ErrorHandlingMixin: Failed to handle error: $e');
      }

      // Try to log the original error with minimal context
      try {
        _logErrorAsync(
          ref,
          operation: operation,
          error: error,
          stackTrace: stackTrace,
          additionalContext: {'fallbackError': e.toString()},
          reason: 'Error in $operation (fallback)',
          severity: ErrorSeverity.critical,
        );
      } catch (fallbackError) {
        // Last resort - just print to console
        if (kDebugMode) {
          print(
              'ErrorHandlingMixin: Complete failure in error handling: $fallbackError');
        }
      }
    }
  }

  /// Safely gets raw data preview for logging
  ///
  /// This method safely converts raw data to a string for logging purposes.
  /// It's specifically designed for parsing errors where raw data context is important.
  ///
  /// Features:
  /// - Null safety (returns 'null' for null input)
  /// - Size limiting (truncates to 200 characters)
  /// - Error handling (fallback if toString() fails)
  ///
  /// Parameters:
  /// - [rawData]: The raw data to convert (usually a Map<String, dynamic>)
  ///
  /// Returns:
  /// - A string representation of the data (truncated if too long)
  /// - 'null' if the input is null
  /// - Error message if conversion fails
  String _getRawDataPreview(Map<String, dynamic>? rawData) {
    if (rawData == null) return 'null';

    try {
      final dataString = rawData.toString();
      if (dataString.length <= 200) {
        return dataString;
      }

      // Truncate to 200 characters to prevent memory issues
      return '${dataString.substring(0, 200)}...';
    } catch (e) {
      // Fallback if toString() fails
      return 'Failed to convert raw data: ${e.toString()}';
    }
  }
}
