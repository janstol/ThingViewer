# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- A "Last entry time" setting controls whether each field's "Last entry" line on the channel detail screen shows the timestamp, a relative age ("5 min ago"), or both (default). The age updates while the screen is open.
- The newest channel status message from ThingSpeak now shows on the channel detail screen, tappable to a log of recent status messages.
- A field whose readings are sparser than the channel detail screen's feed window (e.g. one value per few hundred entries) now still shows up, instead of being silently dropped.
- Field chart screen can now toggle to a paginated table view of the same data (timestamp and value, newest first).

### Changed

- Field chart pinch-zoom and panning are smoother, especially on dense channels: derived chart data is now cached instead of being recomputed on every frame.
- The channel detail screen loads faster, fetching channel info and feed data in parallel instead of sequentially.
- Release builds are now obfuscated, with debug symbols uploaded separately for de-obfuscating crash reports, and no longer bundle unused icon source images. Both reduce app size.

### Fixed

- API requests now time out after 20 seconds instead of leaving the chart or detail screen on a spinner indefinitely on a stalled connection.
- Rapidly changing a field chart's date range no longer occasionally leaves a stale, older result on screen if a newer range finishes fetching first.
- Backup import and export now work on macOS instead of failing to open a file dialog.
- The web and macOS builds now use the ThingViewer icon instead of the default Flutter logo.

## [0.10.0] - 2026-07-27

### Added

- Channel descriptions from ThingSpeak are now shown on the channel detail screen.
- Website and source-code links (`url` / `github_url`) from ThingSpeak are now shown as buttons on the channel detail screen, when set.
- A "Start screen" setting lets you open the app directly on a chosen saved channel's detail screen instead of the channel list.
- Pull-to-refresh on the channel detail screen re-fetches the channel by swiping down, in addition to the existing AppBar refresh button.
- A "Timezone" setting (off by default) appends the UTC offset or zone name to the "Last entry" readout and chart tooltip.
- Per-field chart settings, reachable via a new AppBar button on the field chart screen: chart type (line, spline, or step), a custom title, X/Y axis labels, Y-axis min/max, fixed decimal rounding, and a "show change between readings" toggle for turning a monotonically increasing counter into a per-reading rate. Settings are local to the app and persist per field.
- A Column chart type, added to the per-field chart type picker above. Bars support the same pinch-zoom and pan as the other chart types, and dense windows are automatically downsampled for display.
- A "Source code" link to the app's GitHub repo, added to the Settings → Info section.
- The channel description on the channel detail screen is now selectable, so it can be copied.
- Saved channels can now be edited (server URL, channel ID, public/private, API key) via a new edit button on the channel detail screen, instead of requiring delete-and-re-add.
- The channel list now shows an "Authentication failed" indicator on any saved channel whose last refresh failed due to invalid credentials.
- A Settings → Backup section lets you export saved channels, app settings, and per-field chart overrides to a single JSON file (including API keys, so private channels restore without needing to be re-authenticated), and import that file back in with a choice of replacing everything or only adding channels not already saved.

### Fixed

- Field values are no longer rounded to 2 decimal places on the channel detail readout and chart tooltip, which flattened high-precision channels into apparently unchanging graphs. Values now show a minimum of 2 and a maximum of 6 decimal places.
- Field charts now paginate past ThingSpeak's 8000-entry-per-request cap instead of silently showing only the newest ~8000 points of a requested range. A notice is shown if a range is so dense the app's page budget is exhausted before the full range is covered.
- The channel detail screen now fetches the last 100 entries (was 1) before deciding which fields have no data, so fields not written in the very latest entry no longer disappear from the field list and become unreachable.
- Re-selecting a date range that falls in the gap between two previously viewed ranges now fetches from the API instead of incorrectly serving an empty/partial result from cache.
- `NaN`/`Infinity` field values (and numeric-typed, not just string-typed, JSON field values) from the ThingSpeak API no longer blank an entire chart or throw; they are parsed without error and non-finite readings are skipped. Feed values are also sorted by timestamp after parsing, since ThingSpeak orders `feeds` by entry ID rather than time.
- The field chart filter sheet's From/To fields are tappable again and now let you pick a time in addition to a date, so choosing "today" as the end date includes today's readings instead of excluding them. Values are clamped so From/To can't cross each other or exceed the current time.
- A field chart's default view now anchors to the field's last known reading instead of always to the current time, so a field that hasn't reported recently no longer opens on an empty "No values for the selected data range" chart.

### Changed

- Settings screen tiles are now grouped under section headers (Appearance, General, Date & time, Info).
- Bumped the Flutter SDK to 3.44.8, unblocking Dependabot updates for `path_provider`, `package_info_plus`, and `mockito` that require a newer Dart SDK.
- Enabled optimized resource shrinking for release builds (Android Gradle plugin 8.13.2, Gradle 8.14.5), reducing app bundle size. Removed the deprecated Jetifier flag.
- macOS Runner now embeds Flutter plugins via Swift Package Manager instead of CocoaPods, following Flutter 3.44.8's default. `Podfile.lock` no longer lists plugin pods.
- The Add Channel form's API key field now names the exact key to paste: the channel's Read API Key, not the Write or account User API Key.

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

[0.10.0]: https://github.com/janstol/ThingViewer/releases/tag/v0.10.0
[0.9.0]: https://github.com/janstol/ThingViewer/releases/tag/v0.9.0
