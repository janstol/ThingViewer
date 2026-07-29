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
  String get editChannelTitle => 'Edit Channel';

  @override
  String get editChannelTooltip => 'Edit channel';

  @override
  String get channelListAuthError => 'Authentication failed';

  @override
  String get fieldServerUrl => 'Server URL';

  @override
  String get fieldChannelId => 'Channel ID';

  @override
  String get fieldPublic => 'Public';

  @override
  String get fieldPrivate => 'Private';

  @override
  String get fieldApiKey => 'Read API Key';

  @override
  String get fieldApiKeyHelper =>
      'Required for private channels. Find it on the channel\'s API Keys tab on ThingSpeak.';

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
  String get entryAgeJustNow => 'just now';

  @override
  String entryAgeMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String entryAgeHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String entryAgeDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String entryAgeMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String entryAgeYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get fieldChartNoValues => 'No values for the selected date range.';

  @override
  String get fieldChartNoValuesInZoom => 'No data at this zoom level.';

  @override
  String get fieldChartTruncated =>
      'Only part of this range could be loaded — the channel has more data than a single request can return.';

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
  String get settingsTimezone => 'Timezone display';

  @override
  String get settingsTimezoneChoose => 'Choose timezone display';

  @override
  String get settingsTimezoneOff => 'Off';

  @override
  String get settingsTimezoneOffset => 'UTC offset';

  @override
  String get settingsTimezoneName => 'Name';

  @override
  String get settingsEntryTime => 'Last entry time';

  @override
  String get settingsEntryTimeChoose => 'Choose last entry time display';

  @override
  String get settingsEntryTimeAbsolute => 'Timestamp';

  @override
  String get settingsEntryTimeAge => 'Relative age';

  @override
  String get settingsEntryTimeBoth => 'Both';

  @override
  String get settingsStartScreen => 'Start screen';

  @override
  String get settingsStartScreenChoose => 'Choose start screen';

  @override
  String get settingsStartScreenChannelList => 'Channel list';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionDateTime => 'Date & time';

  @override
  String get settingsSectionBackup => 'Backup';

  @override
  String get settingsSectionInfo => 'Info';

  @override
  String get settingsExport => 'Export';

  @override
  String get settingsExportSubtitle =>
      'Includes API keys for private channels. Store the file securely!';

  @override
  String get settingsImport => 'Import';

  @override
  String get backupImportTitle => 'Import backup';

  @override
  String backupImportSummary(String summary) {
    return 'This backup contains $summary.';
  }

  @override
  String backupSummaryChannels(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '1 channel',
    );
    return '$_temp0';
  }

  @override
  String get backupSummarySettings => 'app settings';

  @override
  String backupSummaryFieldSettings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chart settings',
      one: '1 chart setting',
    );
    return '$_temp0';
  }

  @override
  String get backupSummaryEmpty => 'nothing to import';

  @override
  String get backupModeReplace => 'Replace everything';

  @override
  String get backupModeReplaceDescription =>
      'Overwrites all saved channels, app settings, and chart overrides with this backup\'s contents.';

  @override
  String get backupModeAddChannels => 'Add channels only';

  @override
  String get backupModeAddChannelsDescription =>
      'Adds channels from the backup that aren\'t already saved. Existing channels, app settings, and chart overrides are left unchanged.';

  @override
  String get backupImportConfirm => 'Import';

  @override
  String get backupErrorNotABackup => 'This file isn\'t a ThingViewer backup.';

  @override
  String get backupErrorNewerVersion =>
      'This backup was created by a newer version of the app.';

  @override
  String get backupErrorMalformed =>
      'This backup file is corrupted or unreadable.';

  @override
  String get backupErrorFilePicker => 'Couldn\'t open the file picker.';

  @override
  String get backupExportSuccess => 'Backup saved';

  @override
  String get backupImportSuccess => 'Backup imported';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get settingsSourceCode => 'Source code';

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
  String get errorApiCredentials =>
      'ThingSpeak didn\'t accept that channel ID and API key together. Each channel has its own key, so double check both.';

  @override
  String get errorApiCredentialsDetail =>
      'ThingSpeak didn\'t accept this channel\'s API key. If you rotated the key on ThingSpeak, tap Edit above to update it here.';

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

  @override
  String get fieldSettingsTooltip => 'Chart settings';

  @override
  String get fieldSettingsTitle => 'Chart settings';

  @override
  String get fieldSettingsSectionChart => 'Chart';

  @override
  String get fieldSettingsSectionAxis => 'Axis';

  @override
  String get fieldSettingsSectionData => 'Data';

  @override
  String get fieldSettingsType => 'Type';

  @override
  String get fieldSettingsTypeChoose => 'Choose chart type';

  @override
  String get fieldSettingsTypeLine => 'Line';

  @override
  String get fieldSettingsTypeSpline => 'Spline';

  @override
  String get fieldSettingsTypeStep => 'Step';

  @override
  String get fieldSettingsTypeColumn => 'Column';

  @override
  String get fieldSettingsTypeScatter => 'Scatter';

  @override
  String get fieldSettingsChartTitle => 'Title';

  @override
  String get fieldSettingsXAxisLabel => 'X-axis label';

  @override
  String get fieldSettingsYAxisLabel => 'Y-axis label';

  @override
  String get fieldSettingsAuto => 'auto';

  @override
  String get fieldSettingsYMin => 'Y-axis min';

  @override
  String get fieldSettingsYMax => 'Y-axis max';

  @override
  String get fieldSettingsRounding => 'Rounding';

  @override
  String get fieldSettingsRoundingAuto => 'auto (2–6)';

  @override
  String get fieldSettingsShowDelta => 'Show change between readings';

  @override
  String get fieldSettingsShowDeltaSubtitle =>
      'Plot the difference between consecutive readings instead of raw values';

  @override
  String get fieldSettingsGapOnInvalid => 'Break line at invalid readings';

  @override
  String get fieldSettingsGapOnInvalidSubtitle =>
      'Show a gap for NaN readings instead of connecting the line across them';

  @override
  String get fieldSettingsReset => 'Reset to defaults';
}
