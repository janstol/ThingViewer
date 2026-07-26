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
  /// **'API Key'**
  String get fieldApiKey;

  /// No description provided for @fieldApiKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'Required for private channels'**
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

  /// No description provided for @fieldChartNoValues.
  ///
  /// In en, this message translates to:
  /// **'No values for the selected date range.'**
  String get fieldChartNoValues;

  /// No description provided for @fieldChartShowingValues.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Showing 1 value} other{Showing {count} values}}'**
  String fieldChartShowingValues(num count);

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
  /// **'Timezone'**
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

  /// No description provided for @settingsSectionInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get settingsSectionInfo;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

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
  /// **'Please check your channel ID and API key.'**
  String get errorApiCredentials;

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
