## 2.0.0

* **Breaking:** Mixin no longer takes `Ref`; you must implement `ErrorHandlingService get errorHandlingService` and call `handleError(operation: ..., error: ...)` without a `ref` argument.
* State-management agnostic: supply the service via the getter with any DI (Riverpod, Provider, GetIt, Bloc, GetX).
* Migration: add the getter (e.g. for Riverpod: `ErrorHandlingService get errorHandlingService => ref.read(errorHandlingServiceProvider);` or `ref.errorHandlingService`) and remove the `ref` argument from all `handleError` calls.
* Added `ErrorHandlingRefExtension` on Riverpod `Ref` for convenience: `ref.errorHandlingService`.

## 1.0.1

* Updated SDK constraint to `^3.10.8`.
* Updated dependencies: hooks_riverpod, dio, firebase_core, firebase_crashlytics, package_info_plus, flutter_lints.

## 1.0.0

* Initial release.
* `ErrorHandlingMixin` with unified `handleError` and automatic categorization/severity.
* `ErrorHandlingService` (Firebase Crashlytics) with Flutter/platform/zoned handlers.
* `errorHandlingServiceProvider` for Riverpod (override in main).
* Optional `CrashlyticsNavigatorObserver` for route breadcrumbs.
