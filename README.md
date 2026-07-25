# ThingViewer

Mobile app for viewing and visualizing data from [ThingSpeak](https://thingspeak.com/) channels, built with Flutter.

[![CI](https://github.com/janstol/ThingViewer/actions/workflows/ci.yml/badge.svg)](https://github.com/janstol/ThingViewer/actions/workflows/ci.yml)
[![Demo](https://img.shields.io/badge/demo-WEB-blue)](https://janstol.github.io/ThingViewer/)

<a href='https://play.google.com/store/apps/details?id=dev.stol.thingviewer'>
<img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' width=150/>
</a>

## Features

- Browse and manage multiple ThingSpeak channels
- View latest field values per channel
- Visualize field data as line charts with date range filtering
- Supports public and private (API key) channels
- Custom server URL (self-hosted ThingSpeak instances)
- Light / dark / system theme
- Configurable date and time formats
- Responsive layout — master-detail split on tablets

Android is the actively supported and tested target; iOS/macOS/Windows/Linux/Web build but aren't part of CI.

## Development

### Requirements

- [mise](https://mise.jdx.dev/) — manages the Flutter version (`mise.toml` pins it)
- Flutter 3.35.7 / Dart 3.9.2

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
| Charts | `fl_chart` |
| Localisation | Flutter built-in ARB (`intl`) |
| App info | `package_info_plus` |
| URL handling | `url_launcher` |
| State management | `ChangeNotifier` + `ListenableBuilder` (built-in) |

## License

MIT
