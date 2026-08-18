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
  String get channelListPublicSemantics => 'Public channel';

  @override
  String get channelListPrivateSemantics => 'Private channel';

  @override
  String get channelListDeleteSemantics => 'Delete channel';

  @override
  String get channelListCorruptedTitle => 'Saved channels couldn\'t be read';

  @override
  String get channelListCorruptedText =>
      'The data is unreadable but hasn\'t been overwritten. You can restore it from a backup, save the raw data to look at it later, or discard it and start fresh.';

  @override
  String get channelListCorruptedSave => 'Save raw data';

  @override
  String get channelListCorruptedDiscard => 'Discard and start fresh';

  @override
  String get channelListIssueBannerText =>
      'Some saved data couldn\'t be fully read.';

  @override
  String get channelListIssueBannerDismiss => 'Dismiss';

  @override
  String get channelListIssueBannerAction => 'Details';

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
  String get channelDetailStatus => 'Status';

  @override
  String get channelDetailFieldsSection => 'Fields';

  @override
  String channelDetailCachedData(String age) {
    return 'Showing data from $age';
  }

  @override
  String channelDetailRefreshFailedCached(String age) {
    return 'Refresh failed. Showing data from $age';
  }

  @override
  String get channelDetailRefreshingSemantics => 'Refreshing';

  @override
  String get channelStatusTitle => 'Status log';

  @override
  String get channelStatusEmpty => 'No status messages for this channel.';

  @override
  String get channelStatusViewLog => 'View log';

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
  String get fieldChartStatSum => 'Sum';

  @override
  String get fieldChartStatAverage => 'Avg';

  @override
  String get fieldChartStatMin => 'Min';

  @override
  String get fieldChartStatMax => 'Max';

  @override
  String get fieldChartStatAverageSpoken => 'Average';

  @override
  String get fieldChartStatMinSpoken => 'Minimum';

  @override
  String get fieldChartStatMaxSpoken => 'Maximum';

  @override
  String get fieldTableTooltip => 'Table view';

  @override
  String get fieldChartTooltip => 'Chart view';

  @override
  String get fieldTableColumnTime => 'Time';

  @override
  String get fieldTableColumnValue => 'Value';

  @override
  String fieldTablePage(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String get fieldTablePreviousPage => 'Previous page';

  @override
  String get fieldTableNextPage => 'Next page';

  @override
  String get csvExportTooltip => 'Export CSV';

  @override
  String get csvExportTitle => 'Export CSV';

  @override
  String get csvExportModeRaw => 'Raw';

  @override
  String get csvExportModeRawSubtitle =>
      'ISO timestamps in UTC and full-precision values, unaffected by display settings.';

  @override
  String get csvExportModeFormatted => 'Formatted';

  @override
  String get csvExportModeFormattedSubtitle =>
      'Timestamps and values as shown on screen, using the current date/time and rounding settings.';

  @override
  String get csvExportAction => 'Export';

  @override
  String get csvExportSuccess => 'CSV saved';

  @override
  String fieldChartSemantics(
    String title,
    num count,
    String min,
    String max,
    String latest,
    String latestTime,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$title chart. $_temp0, ranging from $min to $max. Latest value $latest at $latestTime. Use Table view to browse individual readings.';
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
      'Save your channels, settings, and chart overrides to a file.';

  @override
  String get settingsImport => 'Import';

  @override
  String get settingsRecoverData => 'Recover unreadable data';

  @override
  String get backupExportTitle => 'Export backup';

  @override
  String get backupExportModeFull => 'Full backup';

  @override
  String get backupExportModeFullSubtitle =>
      'Includes API keys for private channels. Store the file securely!';

  @override
  String get backupExportModeNoKeys => 'Without API keys';

  @override
  String get backupExportModeNoKeysSubtitle =>
      'Safe to share or attach to a bug report. Private channels will need their API key re-entered after importing.';

  @override
  String get backupExportAction => 'Export';

  @override
  String get backupImportTitle => 'Import backup';

  @override
  String backupImportMissingKeys(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count private channels have no API key and will need one re-entered after importing.',
      one:
          '1 private channel has no API key and will need one re-entered after importing.',
    );
    return '$_temp0';
  }

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
  String get recoveryTitle => 'Recover data';

  @override
  String get recoveryImportBackup => 'Import a backup';

  @override
  String get recoveryNothingToRecover => 'Nothing to recover.';

  @override
  String get recoveryStoreChannels => 'Saved channels';

  @override
  String get recoveryStorePinnedFields => 'Pinned fields';

  @override
  String get recoveryStoreChartSettings => 'Chart settings';

  @override
  String get recoveryStoreCachedValues => 'Cached values';

  @override
  String get recoveryIssueTotal => 'This data couldn\'t be read at all.';

  @override
  String recoveryIssuePartial(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries couldn\'t be read and were skipped.',
      one: '1 entry couldn\'t be read and was skipped.',
    );
    return '$_temp0';
  }

  @override
  String get recoverySaveRawData => 'Save raw data';

  @override
  String get recoveryDiscard => 'Discard';

  @override
  String get recoverySaveSuccess => 'Raw data saved';

  @override
  String get recoveryDiscardTitle => 'Discard unreadable data?';

  @override
  String recoveryDiscardText(String name) {
    return 'This permanently deletes the unreadable data for $name. This cannot be undone.';
  }

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
  String get labelSaving => 'Saving';

  @override
  String get labelLoading => 'Loading';

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
      'ThingSpeak didn\'t accept this channel\'s API key. If you rotated the key on ThingSpeak, use Edit channel to update it.';

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
  String get fieldSettingsSectionStats => 'Stats bar';

  @override
  String get fieldSettingsSectionMarkers => 'Chart markers';

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
  String get fieldSettingsShowSum => 'Show sum';

  @override
  String get fieldSettingsShowAverage => 'Show average';

  @override
  String get fieldSettingsShowMin => 'Show minimum';

  @override
  String get fieldSettingsShowMax => 'Show maximum';

  @override
  String get fieldSettingsMarkMin => 'Mark minimum on chart';

  @override
  String get fieldSettingsMarkMax => 'Mark maximum on chart';

  @override
  String get fieldSettingsReset => 'Reset to defaults';

  @override
  String get pinnedSectionTitle => 'Pinned fields';

  @override
  String get channelListSectionTitle => 'Channels';

  @override
  String get pinnedSectionEditTooltip => 'Edit pinned fields';

  @override
  String get pinnedFieldUnavailable => 'Unavailable';

  @override
  String get pinFieldTooltip => 'Pin field';

  @override
  String get unpinFieldTooltip => 'Unpin field';

  @override
  String get pinnedEditTitle => 'Pinned fields';

  @override
  String get pinnedEditEmpty =>
      'No saved channels. Add a channel first to pin its fields.';

  @override
  String get pinnedEditChannelLoadFailed =>
      'Couldn\'t load fields for this channel.';

  @override
  String get settingsPinnedFields => 'Pinned fields';

  @override
  String get importPreviewSectionFile => 'File';

  @override
  String get importPreviewSectionChannels => 'Channels';

  @override
  String get importPreviewSectionSettings => 'App settings';

  @override
  String get importPreviewSectionOnlyHere => 'Only on this device';

  @override
  String get importPreviewSectionOtherOverrides => 'Other chart overrides';

  @override
  String importPreviewExportedAt(String date) {
    return 'Exported $date';
  }

  @override
  String importPreviewAppVersion(String version) {
    return 'App version $version';
  }

  @override
  String get importPreviewNoApiKeys =>
      'API keys were excluded from this backup.';

  @override
  String get importPreviewStatusNew => 'NEW';

  @override
  String get importPreviewStatusUpdate => 'UPDATE';

  @override
  String get importPreviewStatusUnchanged => 'UNCHANGED';

  @override
  String get importPreviewChangeName => 'Name';

  @override
  String get importPreviewChangeApiKey => 'API key changed';

  @override
  String get importPreviewChangeVisibility => 'Visibility';

  @override
  String get importPreviewNeedsApiKey =>
      'Needs an API key re-entered after importing';

  @override
  String importPreviewChartOverrides(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chart overrides',
      one: '1 chart override',
    );
    return '$_temp0';
  }

  @override
  String importPreviewPinnedFields(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pinned fields',
      one: '1 pinned field',
    );
    return '$_temp0';
  }

  @override
  String importPreviewValueChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get importPreviewValueSame => 'unchanged';

  @override
  String get importPreviewSelectAll => 'Select all';

  @override
  String get importPreviewSelectNone => 'Select none';

  @override
  String get importPreviewRemoveMissing => 'Remove channels not in this backup';

  @override
  String get importPreviewRemoveMissingDescription =>
      'Deletes saved channels that aren\'t present in this file.';

  @override
  String get importPreviewNothingToImport =>
      'This backup has nothing to import.';
}
