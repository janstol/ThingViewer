# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Channel descriptions from ThingSpeak are now shown on the channel detail screen.
- Website and source-code links (`url` / `github_url`) from ThingSpeak are now shown as buttons on the channel detail screen, when set.

### Fixed

- Field values are no longer rounded to 2 decimal places on the channel detail readout and chart tooltip, which flattened high-precision channels into apparently unchanging graphs. Values now show a minimum of 2 and a maximum of 6 decimal places.

### Changed

- Bumped the Flutter SDK to 3.44.8, unblocking Dependabot updates for `path_provider`, `package_info_plus`, and `mockito` that require a newer Dart SDK.
- Enabled optimized resource shrinking for release builds (Android Gradle plugin 8.13.2, Gradle 8.14.5), reducing app bundle size. Removed the deprecated Jetifier flag.

## [0.9.0] - 2026-07-25

Open-source release: rewritten from a BLoC/get_it/clean-architecture layout into a flat `ChangeNotifier` app, with a one-time Hive → SharedPreferences migration to carry existing users' channels and settings across.

### Added

- Material 3 theme with explicit brand colour roles (blue app bar, green FAB) restoring the look of the earlier Material 2 release.
- `BrandColors` theme extension for chart/data-accent colours with WCAG AA-compliant contrast in both light and dark mode.

### Fixed

- Custom server URLs (self-hosted ThingSpeak instances) no longer drop the port or base path when building API requests.
- API keys are no longer at risk of appearing in device logs on request failure.
- Charts for a field with a single data point no longer produce a zero-width x-axis range.
- Selected channel-list tiles no longer render their text/icon in brandGreen (2.43:1 on white, fails WCAG AA); selection is conveyed by the tile background only.

### Changed

- Migrated from Hive/get_it/BLoC to `SharedPreferences` + `ChangeNotifier`.
- Updated dependencies to their latest versions compatible with existing constraints (`build_runner`, `equatable`, `path_provider_android`, and others).

[0.9.0]: https://github.com/janstol/ThingViewer/releases/tag/v0.9.0
