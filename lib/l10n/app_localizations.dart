import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ThingViewer'**
  String get appName;

  /// No description provided for @channelListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved channels. Tap + to add one.'**
  String get channelListEmpty;

  /// No description provided for @channelListSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a channel'**
  String get channelListSelectHint;

  /// No description provided for @addChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Channel'**
  String get addChannelTitle;

  /// No description provided for @addChannelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add channel'**
  String get addChannelTooltip;

  /// No description provided for @editChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Channel'**
  String get editChannelTitle;

  /// No description provided for @editChannelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit channel'**
  String get editChannelTooltip;

  /// No description provided for @channelListAuthError.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get channelListAuthError;

  /// No description provided for @channelListPublicSemantics.
  ///
  /// In en, this message translates to:
  /// **'Public channel'**
  String get channelListPublicSemantics;

  /// No description provided for @channelListPrivateSemantics.
  ///
  /// In en, this message translates to:
  /// **'Private channel'**
  String get channelListPrivateSemantics;

  /// No description provided for @channelListDeleteSemantics.
  ///
  /// In en, this message translates to:
  /// **'Delete channel'**
  String get channelListDeleteSemantics;

  /// No description provided for @channelListCorruptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved channels couldn\'t be read'**
  String get channelListCorruptedTitle;

  /// No description provided for @channelListCorruptedText.
  ///
  /// In en, this message translates to:
  /// **'The data is unreadable but hasn\'t been overwritten. You can restore it from a backup, save the raw data to look at it later, or discard it and start fresh.'**
  String get channelListCorruptedText;

  /// No description provided for @channelListCorruptedSave.
  ///
  /// In en, this message translates to:
  /// **'Save raw data'**
  String get channelListCorruptedSave;

  /// No description provided for @channelListCorruptedDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard and start fresh'**
  String get channelListCorruptedDiscard;

  /// No description provided for @channelListIssueBannerText.
  ///
  /// In en, this message translates to:
  /// **'Some saved data couldn\'t be fully read.'**
  String get channelListIssueBannerText;

  /// No description provided for @channelListIssueBannerDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get channelListIssueBannerDismiss;

  /// No description provided for @channelListIssueBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get channelListIssueBannerAction;

  /// No description provided for @fieldServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get fieldServerUrl;

  /// No description provided for @fieldChannelId.
  ///
  /// In en, this message translates to:
  /// **'Channel ID'**
  String get fieldChannelId;

  /// No description provided for @fieldPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get fieldPublic;

  /// No description provided for @fieldPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get fieldPrivate;

  /// No description provided for @fieldApiKey.
  ///
  /// In en, this message translates to:
  /// **'Read API Key'**
  String get fieldApiKey;

  /// No description provided for @fieldApiKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'Required for private channels. Find it on the channel\'s API Keys tab on ThingSpeak.'**
  String get fieldApiKeyHelper;

  /// No description provided for @channelDetailRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get channelDetailRefresh;

  /// No description provided for @channelDetailLastEntry.
  ///
  /// In en, this message translates to:
  /// **'Last entry'**
  String get channelDetailLastEntry;

  /// No description provided for @channelDetailNoFields.
  ///
  /// In en, this message translates to:
  /// **'No fields found for this channel.'**
  String get channelDetailNoFields;

  /// No description provided for @channelDetailWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get channelDetailWebsite;

  /// No description provided for @channelDetailSource.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get channelDetailSource;

  /// No description provided for @channelDetailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get channelDetailStatus;

  /// No description provided for @channelDetailFieldsSection.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get channelDetailFieldsSection;

  /// No description provided for @channelDetailCachedData.
  ///
  /// In en, this message translates to:
  /// **'Showing data from {age}'**
  String channelDetailCachedData(String age);

  /// No description provided for @channelDetailRefreshFailedCached.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed. Showing data from {age}'**
  String channelDetailRefreshFailedCached(String age);

  /// No description provided for @channelDetailRefreshingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Refreshing'**
  String get channelDetailRefreshingSemantics;

  /// No description provided for @channelStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status log'**
  String get channelStatusTitle;

  /// No description provided for @channelStatusEmpty.
  ///
  /// In en, this message translates to:
  /// **'No status messages for this channel.'**
  String get channelStatusEmpty;

  /// No description provided for @channelStatusViewLog.
  ///
  /// In en, this message translates to:
  /// **'View log'**
  String get channelStatusViewLog;

  /// No description provided for @entryAgeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get entryAgeJustNow;

  /// No description provided for @entryAgeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} min ago}}'**
  String entryAgeMinutes(num count);

  /// No description provided for @entryAgeHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String entryAgeHours(num count);

  /// No description provided for @entryAgeDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String entryAgeDays(num count);

  /// No description provided for @entryAgeMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String entryAgeMonths(num count);

  /// No description provided for @entryAgeYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String entryAgeYears(num count);

  /// No description provided for @fieldChartNoValues.
  ///
  /// In en, this message translates to:
  /// **'No values for the selected date range.'**
  String get fieldChartNoValues;

  /// No description provided for @fieldChartNoValuesInZoom.
  ///
  /// In en, this message translates to:
  /// **'No data at this zoom level.'**
  String get fieldChartNoValuesInZoom;

  /// No description provided for @fieldChartTruncated.
  ///
  /// In en, this message translates to:
  /// **'Only part of this range could be loaded — the channel has more data than a single request can return.'**
  String get fieldChartTruncated;

  /// No description provided for @fieldChartShowingValues.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Showing 1 value} other{Showing {count} values}}'**
  String fieldChartShowingValues(num count);

  /// No description provided for @fieldTableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Table view'**
  String get fieldTableTooltip;

  /// No description provided for @fieldChartTooltip.
  ///
  /// In en, this message translates to:
  /// **'Chart view'**
  String get fieldChartTooltip;

  /// No description provided for @fieldTableColumnTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fieldTableColumnTime;

  /// No description provided for @fieldTableColumnValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get fieldTableColumnValue;

  /// No description provided for @fieldTablePage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String fieldTablePage(int page, int pages);

  /// No description provided for @fieldTablePreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get fieldTablePreviousPage;

  /// No description provided for @fieldTableNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get fieldTableNextPage;

  /// No description provided for @csvExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get csvExportTooltip;

  /// No description provided for @csvExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get csvExportTitle;

  /// No description provided for @csvExportModeRaw.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get csvExportModeRaw;

  /// No description provided for @csvExportModeRawSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ISO timestamps in UTC and full-precision values, unaffected by display settings.'**
  String get csvExportModeRawSubtitle;

  /// No description provided for @csvExportModeFormatted.
  ///
  /// In en, this message translates to:
  /// **'Formatted'**
  String get csvExportModeFormatted;

  /// No description provided for @csvExportModeFormattedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Timestamps and values as shown on screen, using the current date/time and rounding settings.'**
  String get csvExportModeFormattedSubtitle;

  /// No description provided for @csvExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get csvExportAction;

  /// No description provided for @csvExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'CSV saved'**
  String get csvExportSuccess;

  /// No description provided for @fieldChartSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title} chart. {count, plural, =1{1 point} other{{count} points}}, ranging from {min} to {max}. Latest value {latest} at {latestTime}. Use Table view to browse individual readings.'**
  String fieldChartSemantics(
    String title,
    num count,
    String min,
    String max,
    String latest,
    String latestTime,
  );

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterTitle;

  /// No description provided for @filterFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get filterFrom;

  /// No description provided for @filterTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get filterTo;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose theme'**
  String get settingsThemeChoose;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get settingsDateFormat;

  /// No description provided for @settingsDateFormatChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose date format'**
  String get settingsDateFormatChoose;

  /// No description provided for @settingsTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get settingsTimeFormat;

  /// No description provided for @settingsTimeFormatChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose time format'**
  String get settingsTimeFormatChoose;

  /// No description provided for @settingsTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone display'**
  String get settingsTimezone;

  /// No description provided for @settingsTimezoneChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose timezone display'**
  String get settingsTimezoneChoose;

  /// No description provided for @settingsTimezoneOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsTimezoneOff;

  /// No description provided for @settingsTimezoneOffset.
  ///
  /// In en, this message translates to:
  /// **'UTC offset'**
  String get settingsTimezoneOffset;

  /// No description provided for @settingsTimezoneName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get settingsTimezoneName;

  /// No description provided for @settingsEntryTime.
  ///
  /// In en, this message translates to:
  /// **'Last entry time'**
  String get settingsEntryTime;

  /// No description provided for @settingsEntryTimeChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose last entry time display'**
  String get settingsEntryTimeChoose;

  /// No description provided for @settingsEntryTimeAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get settingsEntryTimeAbsolute;

  /// No description provided for @settingsEntryTimeAge.
  ///
  /// In en, this message translates to:
  /// **'Relative age'**
  String get settingsEntryTimeAge;

  /// No description provided for @settingsEntryTimeBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get settingsEntryTimeBoth;

  /// No description provided for @settingsStartScreen.
  ///
  /// In en, this message translates to:
  /// **'Start screen'**
  String get settingsStartScreen;

  /// No description provided for @settingsStartScreenChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose start screen'**
  String get settingsStartScreenChoose;

  /// No description provided for @settingsStartScreenChannelList.
  ///
  /// In en, this message translates to:
  /// **'Channel list'**
  String get settingsStartScreenChannelList;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get settingsSectionDateTime;

  /// No description provided for @settingsSectionBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsSectionBackup;

  /// No description provided for @settingsSectionInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get settingsSectionInfo;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExport;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your channels, settings, and chart overrides to a file.'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImport;

  /// No description provided for @settingsRecoverData.
  ///
  /// In en, this message translates to:
  /// **'Recover unreadable data'**
  String get settingsRecoverData;

  /// No description provided for @backupExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupExportTitle;

  /// No description provided for @backupExportModeFull.
  ///
  /// In en, this message translates to:
  /// **'Full backup'**
  String get backupExportModeFull;

  /// No description provided for @backupExportModeFullSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Includes API keys for private channels. Store the file securely!'**
  String get backupExportModeFullSubtitle;

  /// No description provided for @backupExportModeNoKeys.
  ///
  /// In en, this message translates to:
  /// **'Without API keys'**
  String get backupExportModeNoKeys;

  /// No description provided for @backupExportModeNoKeysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Safe to share or attach to a bug report. Private channels will need their API key re-entered after importing.'**
  String get backupExportModeNoKeysSubtitle;

  /// No description provided for @backupExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExportAction;

  /// No description provided for @backupImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get backupImportTitle;

  /// No description provided for @backupImportMissingKeys.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 private channel has no API key and will need one re-entered after importing.} other{{count} private channels have no API key and will need one re-entered after importing.}}'**
  String backupImportMissingKeys(num count);

  /// No description provided for @backupImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get backupImportConfirm;

  /// No description provided for @backupErrorNotABackup.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a ThingViewer backup.'**
  String get backupErrorNotABackup;

  /// No description provided for @backupErrorNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer version of the app.'**
  String get backupErrorNewerVersion;

  /// No description provided for @backupErrorMalformed.
  ///
  /// In en, this message translates to:
  /// **'This backup file is corrupted or unreadable.'**
  String get backupErrorMalformed;

  /// No description provided for @backupErrorFilePicker.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file picker.'**
  String get backupErrorFilePicker;

  /// No description provided for @backupExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupExportSuccess;

  /// No description provided for @backupImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup imported'**
  String get backupImportSuccess;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover data'**
  String get recoveryTitle;

  /// No description provided for @recoveryImportBackup.
  ///
  /// In en, this message translates to:
  /// **'Import a backup'**
  String get recoveryImportBackup;

  /// No description provided for @recoveryNothingToRecover.
  ///
  /// In en, this message translates to:
  /// **'Nothing to recover.'**
  String get recoveryNothingToRecover;

  /// No description provided for @recoveryStoreChannels.
  ///
  /// In en, this message translates to:
  /// **'Saved channels'**
  String get recoveryStoreChannels;

  /// No description provided for @recoveryStorePinnedFields.
  ///
  /// In en, this message translates to:
  /// **'Pinned fields'**
  String get recoveryStorePinnedFields;

  /// No description provided for @recoveryStoreChartSettings.
  ///
  /// In en, this message translates to:
  /// **'Chart settings'**
  String get recoveryStoreChartSettings;

  /// No description provided for @recoveryStoreCachedValues.
  ///
  /// In en, this message translates to:
  /// **'Cached values'**
  String get recoveryStoreCachedValues;

  /// No description provided for @recoveryIssueTotal.
  ///
  /// In en, this message translates to:
  /// **'This data couldn\'t be read at all.'**
  String get recoveryIssueTotal;

  /// No description provided for @recoveryIssuePartial.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry couldn\'t be read and was skipped.} other{{count} entries couldn\'t be read and were skipped.}}'**
  String recoveryIssuePartial(num count);

  /// No description provided for @recoverySaveRawData.
  ///
  /// In en, this message translates to:
  /// **'Save raw data'**
  String get recoverySaveRawData;

  /// No description provided for @recoveryDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get recoveryDiscard;

  /// No description provided for @recoverySaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Raw data saved'**
  String get recoverySaveSuccess;

  /// No description provided for @recoveryDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unreadable data?'**
  String get recoveryDiscardTitle;

  /// No description provided for @recoveryDiscardText.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the unreadable data for {name}. This cannot be undone.'**
  String recoveryDiscardText(String name);

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @settingsSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get settingsSourceCode;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'With ThingViewer you can easily access and visualize data from ThingSpeak™ channels.\n\nTo learn more about ThingSpeak™, visit '**
  String get aboutText;

  /// No description provided for @aboutThingSpeakUrl.
  ///
  /// In en, this message translates to:
  /// **'https://thingspeak.com'**
  String get aboutThingSpeakUrl;

  /// No description provided for @labelNa.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get labelNa;

  /// No description provided for @labelDelete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get labelDelete;

  /// No description provided for @labelSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get labelSave;

  /// No description provided for @labelSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get labelSaving;

  /// No description provided for @labelLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get labelLoading;

  /// No description provided for @labelApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get labelApply;

  /// No description provided for @labelCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get labelCancel;

  /// No description provided for @errorServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a server URL'**
  String get errorServerUrl;

  /// No description provided for @errorServerUrlValid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid server URL'**
  String get errorServerUrlValid;

  /// No description provided for @errorChannelId.
  ///
  /// In en, this message translates to:
  /// **'Enter a channel ID'**
  String get errorChannelId;

  /// No description provided for @errorChannelIdValid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid channel ID'**
  String get errorChannelIdValid;

  /// No description provided for @errorApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key is required for private channels'**
  String get errorApiKey;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorApiCredentials.
  ///
  /// In en, this message translates to:
  /// **'ThingSpeak didn\'t accept that channel ID and API key together. Each channel has its own key, so double check both.'**
  String get errorApiCredentials;

  /// No description provided for @errorApiCredentialsDetail.
  ///
  /// In en, this message translates to:
  /// **'ThingSpeak didn\'t accept this channel\'s API key. If you rotated the key on ThingSpeak, use Edit channel to update it.'**
  String get errorApiCredentialsDetail;

  /// No description provided for @errorGeneral.
  ///
  /// In en, this message translates to:
  /// **'An error occurred.'**
  String get errorGeneral;

  /// No description provided for @errorDuplicateChannel.
  ///
  /// In en, this message translates to:
  /// **'This channel is already in your list.'**
  String get errorDuplicateChannel;

  /// No description provided for @removeChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove channel?'**
  String get removeChannelTitle;

  /// No description provided for @removeChannelText.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the app? The channel on ThingSpeak will not be affected.'**
  String removeChannelText(String name);

  /// No description provided for @fieldSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Chart settings'**
  String get fieldSettingsTooltip;

  /// No description provided for @fieldSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chart settings'**
  String get fieldSettingsTitle;

  /// No description provided for @fieldSettingsSectionChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get fieldSettingsSectionChart;

  /// No description provided for @fieldSettingsSectionAxis.
  ///
  /// In en, this message translates to:
  /// **'Axis'**
  String get fieldSettingsSectionAxis;

  /// No description provided for @fieldSettingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get fieldSettingsSectionData;

  /// No description provided for @fieldSettingsType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldSettingsType;

  /// No description provided for @fieldSettingsTypeChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose chart type'**
  String get fieldSettingsTypeChoose;

  /// No description provided for @fieldSettingsTypeLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get fieldSettingsTypeLine;

  /// No description provided for @fieldSettingsTypeSpline.
  ///
  /// In en, this message translates to:
  /// **'Spline'**
  String get fieldSettingsTypeSpline;

  /// No description provided for @fieldSettingsTypeStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get fieldSettingsTypeStep;

  /// No description provided for @fieldSettingsTypeColumn.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get fieldSettingsTypeColumn;

  /// No description provided for @fieldSettingsTypeScatter.
  ///
  /// In en, this message translates to:
  /// **'Scatter'**
  String get fieldSettingsTypeScatter;

  /// No description provided for @fieldSettingsChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldSettingsChartTitle;

  /// No description provided for @fieldSettingsXAxisLabel.
  ///
  /// In en, this message translates to:
  /// **'X-axis label'**
  String get fieldSettingsXAxisLabel;

  /// No description provided for @fieldSettingsYAxisLabel.
  ///
  /// In en, this message translates to:
  /// **'Y-axis label'**
  String get fieldSettingsYAxisLabel;

  /// No description provided for @fieldSettingsAuto.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get fieldSettingsAuto;

  /// No description provided for @fieldSettingsYMin.
  ///
  /// In en, this message translates to:
  /// **'Y-axis min'**
  String get fieldSettingsYMin;

  /// No description provided for @fieldSettingsYMax.
  ///
  /// In en, this message translates to:
  /// **'Y-axis max'**
  String get fieldSettingsYMax;

  /// No description provided for @fieldSettingsRounding.
  ///
  /// In en, this message translates to:
  /// **'Rounding'**
  String get fieldSettingsRounding;

  /// No description provided for @fieldSettingsRoundingAuto.
  ///
  /// In en, this message translates to:
  /// **'auto (2–6)'**
  String get fieldSettingsRoundingAuto;

  /// No description provided for @fieldSettingsShowDelta.
  ///
  /// In en, this message translates to:
  /// **'Show change between readings'**
  String get fieldSettingsShowDelta;

  /// No description provided for @fieldSettingsShowDeltaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plot the difference between consecutive readings instead of raw values'**
  String get fieldSettingsShowDeltaSubtitle;

  /// No description provided for @fieldSettingsGapOnInvalid.
  ///
  /// In en, this message translates to:
  /// **'Break line at invalid readings'**
  String get fieldSettingsGapOnInvalid;

  /// No description provided for @fieldSettingsGapOnInvalidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a gap for NaN readings instead of connecting the line across them'**
  String get fieldSettingsGapOnInvalidSubtitle;

  /// No description provided for @fieldSettingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get fieldSettingsReset;

  /// No description provided for @pinnedSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned fields'**
  String get pinnedSectionTitle;

  /// No description provided for @channelListSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channelListSectionTitle;

  /// No description provided for @pinnedSectionEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit pinned fields'**
  String get pinnedSectionEditTooltip;

  /// No description provided for @pinnedFieldUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get pinnedFieldUnavailable;

  /// No description provided for @pinFieldTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pin field'**
  String get pinFieldTooltip;

  /// No description provided for @unpinFieldTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unpin field'**
  String get unpinFieldTooltip;

  /// No description provided for @pinnedEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned fields'**
  String get pinnedEditTitle;

  /// No description provided for @pinnedEditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved channels. Add a channel first to pin its fields.'**
  String get pinnedEditEmpty;

  /// No description provided for @pinnedEditChannelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load fields for this channel.'**
  String get pinnedEditChannelLoadFailed;

  /// No description provided for @settingsPinnedFields.
  ///
  /// In en, this message translates to:
  /// **'Pinned fields'**
  String get settingsPinnedFields;

  /// No description provided for @importPreviewSectionFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get importPreviewSectionFile;

  /// No description provided for @importPreviewSectionChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get importPreviewSectionChannels;

  /// No description provided for @importPreviewSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get importPreviewSectionSettings;

  /// No description provided for @importPreviewSectionOnlyHere.
  ///
  /// In en, this message translates to:
  /// **'Only on this device'**
  String get importPreviewSectionOnlyHere;

  /// No description provided for @importPreviewSectionOtherOverrides.
  ///
  /// In en, this message translates to:
  /// **'Other chart overrides'**
  String get importPreviewSectionOtherOverrides;

  /// No description provided for @importPreviewExportedAt.
  ///
  /// In en, this message translates to:
  /// **'Exported {date}'**
  String importPreviewExportedAt(String date);

  /// No description provided for @importPreviewAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version {version}'**
  String importPreviewAppVersion(String version);

  /// No description provided for @importPreviewNoApiKeys.
  ///
  /// In en, this message translates to:
  /// **'API keys were excluded from this backup.'**
  String get importPreviewNoApiKeys;

  /// No description provided for @importPreviewStatusNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get importPreviewStatusNew;

  /// No description provided for @importPreviewStatusUpdate.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get importPreviewStatusUpdate;

  /// No description provided for @importPreviewStatusUnchanged.
  ///
  /// In en, this message translates to:
  /// **'UNCHANGED'**
  String get importPreviewStatusUnchanged;

  /// No description provided for @importPreviewChangeName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get importPreviewChangeName;

  /// No description provided for @importPreviewChangeApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key changed'**
  String get importPreviewChangeApiKey;

  /// No description provided for @importPreviewChangeVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get importPreviewChangeVisibility;

  /// No description provided for @importPreviewNeedsApiKey.
  ///
  /// In en, this message translates to:
  /// **'Needs an API key re-entered after importing'**
  String get importPreviewNeedsApiKey;

  /// No description provided for @importPreviewChartOverrides.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chart override} other{{count} chart overrides}}'**
  String importPreviewChartOverrides(num count);

  /// No description provided for @importPreviewPinnedFields.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pinned field} other{{count} pinned fields}}'**
  String importPreviewPinnedFields(num count);

  /// No description provided for @importPreviewValueChange.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String importPreviewValueChange(String from, String to);

  /// No description provided for @importPreviewValueSame.
  ///
  /// In en, this message translates to:
  /// **'unchanged'**
  String get importPreviewValueSame;

  /// No description provided for @importPreviewSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get importPreviewSelectAll;

  /// No description provided for @importPreviewSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get importPreviewSelectNone;

  /// No description provided for @importPreviewRemoveMissing.
  ///
  /// In en, this message translates to:
  /// **'Remove channels not in this backup'**
  String get importPreviewRemoveMissing;

  /// No description provided for @importPreviewRemoveMissingDescription.
  ///
  /// In en, this message translates to:
  /// **'Deletes saved channels that aren\'t present in this file.'**
  String get importPreviewRemoveMissingDescription;

  /// No description provided for @importPreviewNothingToImport.
  ///
  /// In en, this message translates to:
  /// **'This backup has nothing to import.'**
  String get importPreviewNothingToImport;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
