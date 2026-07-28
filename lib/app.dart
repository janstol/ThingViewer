import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/thingspeak_api.dart';
import 'backup/backup_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/channel_list/channel_list_screen.dart';
import 'screens/settings/settings_notifier.dart';
import 'storage/channel_storage.dart';
import 'storage/field_settings_storage.dart';
import 'storage/settings_storage.dart';
import 'theme.dart';

class App extends StatefulWidget {
  final ThingSpeakApi api;
  final ChannelStorage channelStorage;
  final SettingsStorage settingsStorage;
  final FieldSettingsStorage fieldSettingsStorage;
  final BackupService backupService;

  const App({
    super.key,
    required this.api,
    required this.channelStorage,
    required this.settingsStorage,
    required this.fieldSettingsStorage,
    required this.backupService,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final SettingsNotifier _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsNotifier(widget.settingsStorage);
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => MaterialApp(
        title: 'ThingViewer',
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        themeMode: _settings.themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: ChannelListScreen(
          api: widget.api,
          channelStorage: widget.channelStorage,
          settings: _settings,
          fieldSettingsStorage: widget.fieldSettingsStorage,
          backupService: widget.backupService,
        ),
      ),
    );
  }
}
