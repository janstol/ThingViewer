# ThingViewer

Mobile app for viewing and visualizing data from [ThingSpeak](https://thingspeak.com/) channels, built with Flutter.

[![CI](https://github.com/janstol/ThingViewer/actions/workflows/ci.yml/badge.svg)](https://github.com/janstol/ThingViewer/actions/workflows/ci.yml)
[![Demo](https://img.shields.io/badge/demo-WEB-blue)](https://janstol.github.io/ThingViewer/)

<a href='https://play.google.com/store/apps/details?id=dev.stol.thingviewer'>
<img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' width=150/>
</a>

## Installation

Google Play is the recommended source and gets automatic updates.

Each [GitHub Release](https://github.com/janstol/ThingViewer/releases/latest) also includes signed APKs (arm64-v8a and armeabi-v7a), for installing without the Play Store, e.g. on de-Googled Android (CalyxOS, GrapheneOS). Works with [Obtainium](https://github.com/ImranR98/Obtainium) for auto-updates.

The GitHub APKs are signed with a different key than the Play Store version (Play re-signs apps with its own key), so switching between the two isn't an in-place update: uninstall the old one first, then use Settings → Backup to carry your saved channels and settings across.

## Screenshots

<p>
<img src="docs/screenshots/phone/01_list_light.png" alt="Channel list with pinned fields, light mode" width="250" />
<img src="docs/screenshots/phone/02_chart24_dark.png" alt="Field chart for the last 24 hours, dark mode" width="250" />
<img src="docs/screenshots/phone/03_detail_light.png" alt="Channel detail, light mode" width="250" />
</p>

## Features

- Browse and manage multiple ThingSpeak channels, public or private (Read API Key), on api.thingspeak.com or a self-hosted server, with a configurable start screen (channel list or a chosen channel's detail screen)
- Pin the fields you check most; pinned fields show their latest value at the top of the channel list
- View latest field values per channel, its status messages, and its description and website/source links when set, with pull-to-refresh
- Last known values from a local cache show immediately, including offline, with a note on how old they are
- Charts for the last hour, 24 hours, 7 days or 30 days, or a custom range, as line, spline, step, or column charts, with minimum, maximum, average and sum for the shown range
- Per-field chart settings: title, axis labels, Y-axis min/max, decimal rounding, default range, min/max markers, and a "show change between readings" mode for counters
- Table of individual readings, with CSV export
- Automatically pages past ThingSpeak's per-request result cap so large date ranges aren't silently truncated; non-finite (`NaN`/`Infinity`) readings are skipped rather than breaking the chart
- Light / dark / system theme
- Configurable date and time formats, with an optional timezone indicator (offset or name)
- Export/import a full backup (saved channels, app settings, pinned fields, and per-field chart overrides) as a single JSON file, with a preview of what an import changes
- Responsive layout: list and detail side by side on tablets

Android is the actively supported and tested target. Web is built and deployed to the [demo](https://janstol.github.io/ThingViewer/) on every push, but isn't covered by automated tests. Android and web are built on every pull request; iOS/macOS/Windows/Linux are build-checked weekly in CI, but aren't otherwise supported or tested.

## Development

### Requirements

- [mise](https://mise.jdx.dev/) — manages the Flutter version (`mise.toml` pins it)
- Flutter 3.50.0 / Dart 3.14.0

Commands below assume an activated mise shell (`mise activate` / `mise shell`). If mise isn't activated, prefix each command with `mise exec --`, e.g. `mise exec -- flutter test`.

### Setup

```bash
# Install Flutter via mise
mise install

# Install dependencies
flutter pub get

# Generate mocks (needed after changing @GenerateMocks annotations)
dart run build_runner build
```

### Running

```bash
flutter run
```

### Tests & analysis

```bash
flutter test
flutter analyze
```

### Release builds

Create `android/key.properties` with your keystore credentials:

```
storePassword=...
keyPassword=...
keyAlias=...
storeFile=path/to/keystore.jks
```

Then build:

```bash
flutter build apk          # Android APK
flutter build appbundle    # Android App Bundle (Play Store)
```

### Updating app icons

Edit `res/images/thingviewer_icon.png` (and `thingviewer_icon_foreground.png` for the adaptive foreground layer), then regenerate:

```bash
dart run flutter_launcher_icons
```

## Tech stack

| Concern | Library |
|---|---|
| HTTP | `http` |
| Local storage | `shared_preferences` |
| File picking | `file_picker` |
| Charts | `fl_chart` |
| Localisation | Flutter built-in ARB (`intl`) |
| App info | `package_info_plus` |
| URL handling | `url_launcher` |
| State management | `ChangeNotifier` + `ListenableBuilder` (built-in) |

## License

MIT
