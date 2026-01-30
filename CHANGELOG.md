## 1.0.0

* Initial release.
* `ErrorHandlingMixin` with unified `handleError` and automatic categorization/severity.
* `ErrorHandlingService` (Firebase Crashlytics) with Flutter/platform/zoned handlers.
* `errorHandlingServiceProvider` for Riverpod (override in main).
* Optional `CrashlyticsNavigatorObserver` for route breadcrumbs.
