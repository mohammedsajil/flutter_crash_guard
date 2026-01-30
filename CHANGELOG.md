## 1.0.1

* Updated SDK constraint to `^3.10.8`.
* Updated dependencies: hooks_riverpod, dio, firebase_core, firebase_crashlytics, package_info_plus, flutter_lints.

## 1.0.0

* Initial release.
* `ErrorHandlingMixin` with unified `handleError` and automatic categorization/severity.
* `ErrorHandlingService` (Firebase Crashlytics) with Flutter/platform/zoned handlers.
* `errorHandlingServiceProvider` for Riverpod (override in main).
* Optional `CrashlyticsNavigatorObserver` for route breadcrumbs.
