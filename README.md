# ThingViewer

Mobile app for viewing and visualizing data from [ThingSpeak](https://thingspeak.com/) channels, built with Flutter.

[![CI](https://github.com/janstol/ThingViewer/actions/workflows/ci.yml/badge.svg)](https://github.com/janstol/ThingViewer/actions/workflows/ci.yml)

<a href='https://play.google.com/store/apps/details?id=dev.stol.thingviewer'>
<img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' width=150/>
</a>
<a href='https://janstol.github.io/ThingViewer/'>
<img alt='Open web demo' src='https://img.shields.io/badge/Web-demo-blue?style=for-the-badge&logo=googlechrome&logoColor=white' height=44/>
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

## Development

### Requirements

- [mise](https://mise.jdx.dev/) — manages the Flutter version (`mise.toml` pins it)
- Flutter 3.35.7 / Dart 3.9.2

### Setup

```bash
# Install Flutter via mise
mise install

# Install dependencies
mise exec -- flutter pub get

# Generate mocks (needed after changing @GenerateMocks annotations)
mise exec -- flutter pub run build_runner build --delete-conflicting-outputs
```

### Running

```bash
mise exec -- flutter run
```

### Tests & analysis

```bash
mise exec -- flutter test
mise exec -- flutter analyze
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
mise exec -- flutter build apk          # Android APK
mise exec -- flutter build appbundle    # Android App Bundle (Play Store)
```

### Updating app icons

Edit `res/images/thingviewer_icon.png` (and `thingviewer_icon_foreground.png` for the adaptive foreground layer), then regenerate:

```bash
mise exec -- flutter pub run flutter_launcher_icons
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
