# Contributing to ThingViewer

Contributions are welcome! ThingViewer is MIT-licensed — by submitting a PR you agree your contribution is released under the same terms.

---

## Reporting bugs & requesting features

Use the [issue templates](https://github.com/janstol/ThingViewer/issues/new/choose) — they prompt for the information needed to act on a report quickly. Please search existing issues before filing a new one.

---

## Development setup

See [README.md § Development](README.md#development) for the full setup. In short:

```bash
mise install          # installs the pinned Flutter version
flutter pub get       # fetch dependencies

# Generate mocks (needed after changing @GenerateMocks annotations)
dart run build_runner build
```

Commands assume an activated mise shell; otherwise prefix each with `mise exec --`.

---

## Tests & analysis

```bash
flutter test                           # run all tests
flutter test test/path/to_test.dart   # run a single test file
flutter analyze                        # static analysis
```

CI runs both `flutter analyze` and `flutter test` on every PR. Please make sure both pass locally before pushing.

---

## Code style

`analysis_options.yaml` enforces:

- `prefer_single_quotes`
- `require_trailing_commas`

Run `flutter analyze` and fix all warnings before opening a PR.

---

## Accessibility

New interactive widgets and screens should ship accessible by default:

- Icon-only buttons need a `tooltip`; standalone informational icons need a `semanticLabel`.
- Multi-part list rows (label + subtitle + trailing icon describing one item) should be wrapped in `MergeSemantics`.
- Section headings should use `Semantics(header: true)`.
- Custom gestures with no visible equivalent (e.g. swipe-to-dismiss) need a matching `CustomSemanticsAction`.
- New colour pairs need a WCAG contrast check added to `test/theme_test.dart`.
- New screens need a case added to `test/a11y_test.dart`, which checks tap target size, labeling, and contrast in both light and dark theme.

---

## Architecture

The app uses a flat, minimal architecture — no BLoC, no get_it, no repository interfaces.

### Directory layout

```
lib/
  main.dart             # Bootstrap: SharedPreferences, ThingSpeakApi, runApp
  app.dart              # MaterialApp + SettingsNotifier (theme, formats)
  theme.dart            # Material 3 AppTheme (light/dark)
  api/
    thingspeak_api.dart # HTTP client + JSON parsing (isolates via compute())
  models/
    channel.dart        # Channel (JSON serialisable, used for storage)
    field.dart          # Field + FieldValue
  storage/
    channel_storage.dart   # Channel list → SharedPreferences as JSON string
    settings_storage.dart  # Theme mode + date/time format preferences
  screens/
    channel_list/       # ChannelListNotifier + ChannelListScreen
    channel_add/        # Form screen (no notifier, stateful widget)
    channel_detail/     # ChannelDetailNotifier + screen
    field_chart/        # FieldChartNotifier + screen (fl_chart)
    settings/           # SettingsNotifier + screen
  l10n/
    app_en.arb          # All UI strings (source of truth)
```

### Key patterns

- **State management** — `ChangeNotifier` + `ListenableBuilder`. Each screen creates its own notifier in `initState` and disposes it in `dispose`.
- **State classes** — Sealed classes with named fields (e.g. `ChannelListLoaded`, `ChannelDetailError`). Exhaustive `switch` in `build()`.
- **Error propagation** — Notifiers catch `ApiException` and store the message in an error state. No `Result` type, no `Failure` hierarchy.
- **Storage** — `ChannelStorage` persists a JSON-encoded list. `SettingsStorage` uses simple int/string keys. Both have synchronous readers and async writers.
- **API** — `ThingSpeakApi` in `lib/api/thingspeak_api.dart`. JSON parsing runs in an isolate via `compute()`. Throws `ApiException` on any error.
- **Charts** — `fl_chart`. `FieldChartNotifier` caches fetched values locally and only calls the API when the requested range exceeds the cache.

---

## Localisation

All user-facing strings live in `lib/l10n/app_en.arb`. After editing that file, regenerate the generated code:

```bash
flutter gen-l10n
```

---

## Pull requests

- Keep PRs focused on a single concern.
- Reference the related issue (`Closes #123`) in the PR description.
- Fill in the PR template (it pre-fills automatically when you open a PR).
- Ensure `flutter analyze` and `flutter test` are green — CI will block merge otherwise.

---

## Code of conduct

Be respectful and assume good faith. Constructive feedback is welcome; personal attacks are not.
