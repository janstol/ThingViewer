// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ThingViewer';

  @override
  String get channelListEmpty => 'No saved channels. Tap + to add one.';

  @override
  String get channelListSelectHint => 'Select a channel';

  @override
  String get addChannelTitle => 'Add Channel';

  @override
  String get addChannelTooltip => 'Add channel';

  @override
  String get fieldServerUrl => 'Server URL';

  @override
  String get fieldChannelId => 'Channel ID';

  @override
  String get fieldPublic => 'Public';

  @override
  String get fieldPrivate => 'Private';

  @override
  String get fieldApiKey => 'API Key';

  @override
  String get fieldApiKeyHelper => 'Required for private channels';

  @override
  String get channelDetailRefresh => 'Refresh';

  @override
  String get channelDetailLastEntry => 'Last entry';

  @override
  String get channelDetailNoFields => 'No fields found for this channel.';

  @override
  String get channelDetailWebsite => 'Website';

  @override
  String get channelDetailSource => 'Source code';

  @override
  String get fieldChartNoValues => 'No values for the selected date range.';

  @override
  String fieldChartShowingValues(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Showing $count values',
      one: 'Showing 1 value',
    );
    return '$_temp0';
  }

  @override
  String get filterTitle => 'Filter';

  @override
  String get filterFrom => 'From';

  @override
  String get filterTo => 'To';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeChoose => 'Choose theme';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsDateFormat => 'Date format';

  @override
  String get settingsDateFormatChoose => 'Choose date format';

  @override
  String get settingsTimeFormat => 'Time format';

  @override
  String get settingsTimeFormatChoose => 'Choose time format';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutText =>
      'With ThingViewer you can easily access and visualize data from ThingSpeak™ channels.\n\nTo learn more about ThingSpeak™, visit ';

  @override
  String get aboutThingSpeakUrl => 'https://thingspeak.com';

  @override
  String get labelNa => 'N/A';

  @override
  String get labelDelete => 'DELETE';

  @override
  String get labelSave => 'Save';

  @override
  String get labelApply => 'Apply';

  @override
  String get labelCancel => 'Cancel';

  @override
  String get errorServerUrl => 'Enter a server URL';

  @override
  String get errorServerUrlValid => 'Enter a valid server URL';

  @override
  String get errorChannelId => 'Enter a channel ID';

  @override
  String get errorChannelIdValid => 'Enter a valid channel ID';

  @override
  String get errorApiKey => 'API key is required for private channels';

  @override
  String get errorNetwork => 'Network error. Please check your connection.';

  @override
  String get errorApiCredentials => 'Please check your channel ID and API key.';

  @override
  String get errorGeneral => 'An error occurred.';

  @override
  String get errorDuplicateChannel => 'This channel is already in your list.';

  @override
  String get removeChannelTitle => 'Remove channel?';

  @override
  String removeChannelText(String name) {
    return 'Remove $name from the app? The channel on ThingSpeak will not be affected.';
  }
}
