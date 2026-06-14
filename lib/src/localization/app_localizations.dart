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
/// import 'localization/app_localizations.dart';
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

  /// Inform the user of the license and means of it's obtainment.
  ///
  /// In en, this message translates to:
  /// **'This application is provided to you under the GNU Affero General Public License version 3.0 or higher. If you have not recieved the license alognside the program, please consult the moonrelay Website for more information.'**
  String get appLicenseNotice;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MOONRELAY'**
  String get appTitle;

  /// No description provided for @areYouSureExit.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the application?'**
  String get areYouSureExit;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Surena Karimpour Ghannadi'**
  String get author;

  /// No description provided for @chatBoxSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send a message!'**
  String get chatBoxSendMessage;

  /// No description provided for @confirmClose.
  ///
  /// In en, this message translates to:
  /// **'Confirm Exit'**
  String get confirmClose;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @directMessages.
  ///
  /// In en, this message translates to:
  /// **'Direct Messages'**
  String get directMessages;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error!'**
  String get error;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @homeserverText.
  ///
  /// In en, this message translates to:
  /// **'Homeserver'**
  String get homeserverText;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @noOrCancellation.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noOrCancellation;

  /// No description provided for @ownProfileDescriptor.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get ownProfileDescriptor;

  /// No description provided for @passwordText.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordText;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and Your Data'**
  String get privacyPolicy;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Moonrelay'**
  String get projectName;

  /// No description provided for @thirdPartyLicense.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get thirdPartyLicense;

  /// No description provided for @usernameText.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameText;

  /// No description provided for @userProfilePageBanner.
  ///
  /// In en, this message translates to:
  /// **'{username}\'s Profile'**
  String userProfilePageBanner(String username);

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning!'**
  String get warning;

  /// No description provided for @yesOrAffirmitive.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yesOrAffirmitive;

  /// No description provided for @chatBoxAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get chatBoxAttach;

  /// No description provided for @chatBoxSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatBoxSend;

  /// No description provided for @chatBoxExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand editor'**
  String get chatBoxExpand;

  /// No description provided for @chatBoxCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chatBoxCollapse;

  /// Label shown in the reply preview banner.
  ///
  /// In en, this message translates to:
  /// **'Replying to {sender}'**
  String chatBoxReplyingTo(String sender);

  /// No description provided for @chatBoxCancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get chatBoxCancelReply;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @encryptionSecurity.
  ///
  /// In en, this message translates to:
  /// **'Encryption & Security'**
  String get encryptionSecurity;

  /// No description provided for @encryptionSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Encryption Setup'**
  String get encryptionSetupTitle;

  /// No description provided for @encryptionCrossSigning.
  ///
  /// In en, this message translates to:
  /// **'Cross-Signing'**
  String get encryptionCrossSigning;

  /// No description provided for @encryptionCrossSigningActive.
  ///
  /// In en, this message translates to:
  /// **'Cross-signing is active'**
  String get encryptionCrossSigningActive;

  /// No description provided for @encryptionCrossSigningInactive.
  ///
  /// In en, this message translates to:
  /// **'Cross-signing is not set up'**
  String get encryptionCrossSigningInactive;

  /// No description provided for @encryptionDeviceVerified.
  ///
  /// In en, this message translates to:
  /// **'This device is verified'**
  String get encryptionDeviceVerified;

  /// No description provided for @encryptionDeviceNotVerified.
  ///
  /// In en, this message translates to:
  /// **'This device is not verified'**
  String get encryptionDeviceNotVerified;

  /// No description provided for @encryptionBootstrap.
  ///
  /// In en, this message translates to:
  /// **'Set Up Encryption'**
  String get encryptionBootstrap;

  /// No description provided for @encryptionReBootstrap.
  ///
  /// In en, this message translates to:
  /// **'Re-run Setup'**
  String get encryptionReBootstrap;

  /// No description provided for @encryptionDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get encryptionDevices;

  /// No description provided for @encryptionDevicesLower.
  ///
  /// In en, this message translates to:
  /// **'devices'**
  String get encryptionDevicesLower;

  /// No description provided for @encryptionManageDevices.
  ///
  /// In en, this message translates to:
  /// **'Manage Devices'**
  String get encryptionManageDevices;

  /// No description provided for @encryptionNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get encryptionNoDevices;

  /// No description provided for @encryptionDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get encryptionDevice;

  /// No description provided for @encryptionThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get encryptionThisDevice;

  /// No description provided for @encryptionDeleteDevice.
  ///
  /// In en, this message translates to:
  /// **'Delete Device'**
  String get encryptionDeleteDevice;

  /// No description provided for @encryptionDeleteDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get encryptionDeleteDeviceConfirm;

  /// No description provided for @encryptionDeviceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Device deleted'**
  String get encryptionDeviceDeleted;

  /// No description provided for @encryptionMarkAsVerified.
  ///
  /// In en, this message translates to:
  /// **'Mark as Verified'**
  String get encryptionMarkAsVerified;

  /// No description provided for @encryptionMarkAsUnverified.
  ///
  /// In en, this message translates to:
  /// **'Mark as Unverified'**
  String get encryptionMarkAsUnverified;

  /// No description provided for @encryptionKeyBackup.
  ///
  /// In en, this message translates to:
  /// **'Key Backup'**
  String get encryptionKeyBackup;

  /// No description provided for @encryptionKeyBackupActive.
  ///
  /// In en, this message translates to:
  /// **'Key backup is enabled'**
  String get encryptionKeyBackupActive;

  /// No description provided for @encryptionKeyBackupInactive.
  ///
  /// In en, this message translates to:
  /// **'Key backup is not enabled'**
  String get encryptionKeyBackupInactive;

  /// No description provided for @encryptionSetupKeyBackup.
  ///
  /// In en, this message translates to:
  /// **'Set Up Key Backup'**
  String get encryptionSetupKeyBackup;

  /// No description provided for @encryptionSetupCrossSigningFirst.
  ///
  /// In en, this message translates to:
  /// **'Set up cross-signing first'**
  String get encryptionSetupCrossSigningFirst;

  /// No description provided for @encryptionVerifiedUsers.
  ///
  /// In en, this message translates to:
  /// **'Verified Users'**
  String get encryptionVerifiedUsers;

  /// No description provided for @encryptionUnverifiedOwn.
  ///
  /// In en, this message translates to:
  /// **'My unverified devices'**
  String get encryptionUnverifiedOwn;

  /// No description provided for @encryptionUnverifiedOther.
  ///
  /// In en, this message translates to:
  /// **'Unverified other users'**
  String get encryptionUnverifiedOther;

  /// No description provided for @encryptionVerifyUser.
  ///
  /// In en, this message translates to:
  /// **'Verify User'**
  String get encryptionVerifyUser;

  /// No description provided for @encryptionUserVerified.
  ///
  /// In en, this message translates to:
  /// **'This user is verified'**
  String get encryptionUserVerified;

  /// No description provided for @encryptionUserNotVerified.
  ///
  /// In en, this message translates to:
  /// **'This user is not verified'**
  String get encryptionUserNotVerified;

  /// No description provided for @encryptionVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get encryptionVerify;

  /// No description provided for @encryptionNoKeyInfo.
  ///
  /// In en, this message translates to:
  /// **'No key information'**
  String get encryptionNoKeyInfo;

  /// No description provided for @encryptionEnabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get encryptionEnabledTitle;

  /// No description provided for @encryptionNotEnabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Not Encrypted'**
  String get encryptionNotEnabledTitle;

  /// No description provided for @encryptionStatusInfo.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption status'**
  String get encryptionStatusInfo;

  /// No description provided for @encryptionDecryptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Decryption failed'**
  String get encryptionDecryptionFailed;

  /// No description provided for @encryptionRequestKeys.
  ///
  /// In en, this message translates to:
  /// **'Request keys'**
  String get encryptionRequestKeys;

  /// No description provided for @encryptionKeysRequested.
  ///
  /// In en, this message translates to:
  /// **'Key request sent to other devices'**
  String get encryptionKeysRequested;

  /// No description provided for @encryptionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Encryption is not supported in this build'**
  String get encryptionUnsupported;

  /// No description provided for @encryptionSetupCrossSigning.
  ///
  /// In en, this message translates to:
  /// **'Set Up Cross-Signing'**
  String get encryptionSetupCrossSigning;

  /// No description provided for @encryptionSetupCrossSigningDesc.
  ///
  /// In en, this message translates to:
  /// **'Cross-signing allows you to verify other users and devices. This will create signing keys that are stored in your encrypted secret storage.'**
  String get encryptionSetupCrossSigningDesc;

  /// No description provided for @encryptionSetupAllKeys.
  ///
  /// In en, this message translates to:
  /// **'Set Up All Keys'**
  String get encryptionSetupAllKeys;

  /// No description provided for @encryptionSkipKeySetup.
  ///
  /// In en, this message translates to:
  /// **'Skip Key Setup'**
  String get encryptionSkipKeySetup;

  /// No description provided for @encryptionExistingSsssFound.
  ///
  /// In en, this message translates to:
  /// **'Existing encrypted secrets storage found'**
  String get encryptionExistingSsssFound;

  /// No description provided for @encryptionWipeExisting.
  ///
  /// In en, this message translates to:
  /// **'Wipe and Start Fresh'**
  String get encryptionWipeExisting;

  /// No description provided for @encryptionKeepExisting.
  ///
  /// In en, this message translates to:
  /// **'Keep Existing'**
  String get encryptionKeepExisting;

  /// No description provided for @encryptionUseExistingSsss.
  ///
  /// In en, this message translates to:
  /// **'Use Existing Secret Storage'**
  String get encryptionUseExistingSsss;

  /// No description provided for @encryptionBadSsss.
  ///
  /// In en, this message translates to:
  /// **'Some secrets could not be read. Continue anyway?'**
  String get encryptionBadSsss;

  /// No description provided for @encryptionContinueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue Anyway'**
  String get encryptionContinueAnyway;

  /// No description provided for @encryptionUnlockSsss.
  ///
  /// In en, this message translates to:
  /// **'Unlock Existing Secrets'**
  String get encryptionUnlockSsss;

  /// No description provided for @encryptionUnlockDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase or recovery key for your existing secret storage.'**
  String get encryptionUnlockDescription;

  /// No description provided for @encryptionEnterRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Enter Recovery Key'**
  String get encryptionEnterRecoveryKey;

  /// No description provided for @encryptionPassphraseOrKey.
  ///
  /// In en, this message translates to:
  /// **'Passphrase or Recovery Key'**
  String get encryptionPassphraseOrKey;

  /// No description provided for @encryptionUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get encryptionUnlock;

  /// No description provided for @encryptionCouldNotUnlock.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock with the provided value'**
  String get encryptionCouldNotUnlock;

  /// No description provided for @encryptionCreatePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Create a Recovery Passphrase'**
  String get encryptionCreatePassphrase;

  /// No description provided for @encryptionSetPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Set Passphrase'**
  String get encryptionSetPassphrase;

  /// No description provided for @encryptionUnlocking.
  ///
  /// In en, this message translates to:
  /// **'Unlocking…'**
  String get encryptionUnlocking;

  /// No description provided for @encryptionCrossSigningExists.
  ///
  /// In en, this message translates to:
  /// **'Cross-signing is already set up'**
  String get encryptionCrossSigningExists;

  /// No description provided for @encryptionRecreateKeys.
  ///
  /// In en, this message translates to:
  /// **'Re-create Keys'**
  String get encryptionRecreateKeys;

  /// No description provided for @encryptionKeepKeys.
  ///
  /// In en, this message translates to:
  /// **'Keep Existing Keys'**
  String get encryptionKeepKeys;

  /// No description provided for @encryptionBackupExists.
  ///
  /// In en, this message translates to:
  /// **'Online key backup already exists'**
  String get encryptionBackupExists;

  /// No description provided for @encryptionRecreateBackup.
  ///
  /// In en, this message translates to:
  /// **'Re-create Backup'**
  String get encryptionRecreateBackup;

  /// No description provided for @encryptionKeepBackup.
  ///
  /// In en, this message translates to:
  /// **'Keep Existing Backup'**
  String get encryptionKeepBackup;

  /// No description provided for @encryptionSetupBackup.
  ///
  /// In en, this message translates to:
  /// **'Set Up Online Key Backup'**
  String get encryptionSetupBackup;

  /// No description provided for @encryptionSetupBackupDesc.
  ///
  /// In en, this message translates to:
  /// **'An encrypted backup of your message keys will be stored on the server so you can recover your conversation history on new devices.'**
  String get encryptionSetupBackupDesc;

  /// No description provided for @encryptionEnableBackup.
  ///
  /// In en, this message translates to:
  /// **'Enable Backup'**
  String get encryptionEnableBackup;

  /// No description provided for @encryptionSkipBackup.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get encryptionSkipBackup;

  /// No description provided for @encryptionVerifyUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify User'**
  String get encryptionVerifyUserTitle;

  /// No description provided for @encryptionVerificationRequest.
  ///
  /// In en, this message translates to:
  /// **'Verification Request'**
  String get encryptionVerificationRequest;

  /// No description provided for @encryptionChooseMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose Verification Method'**
  String get encryptionChooseMethod;

  /// No description provided for @encryptionMethodEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji / Numbers (SAS)'**
  String get encryptionMethodEmoji;

  /// No description provided for @encryptionMethodQr.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get encryptionMethodQr;

  /// No description provided for @encryptionCompareEmojis.
  ///
  /// In en, this message translates to:
  /// **'Compare Emojis'**
  String get encryptionCompareEmojis;

  /// No description provided for @encryptionCompareDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify that the following emojis (or numbers) match on both devices.'**
  String get encryptionCompareDescription;

  /// No description provided for @encryptionDoTheyMatch.
  ///
  /// In en, this message translates to:
  /// **'Do they match?'**
  String get encryptionDoTheyMatch;

  /// No description provided for @encryptionTheyMatch.
  ///
  /// In en, this message translates to:
  /// **'They Match'**
  String get encryptionTheyMatch;

  /// No description provided for @encryptionTheyDontMatch.
  ///
  /// In en, this message translates to:
  /// **'They Don\'t Match'**
  String get encryptionTheyDontMatch;

  /// No description provided for @encryptionWaitingForYou.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you to accept…'**
  String get encryptionWaitingForYou;

  /// No description provided for @encryptionWaitingForOther.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device…'**
  String get encryptionWaitingForOther;

  /// No description provided for @encryptionVerificationWaitingDesc.
  ///
  /// In en, this message translates to:
  /// **'The verification request has been sent.'**
  String get encryptionVerificationWaitingDesc;

  /// No description provided for @encryptionWaitingForSas.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the emoji/number comparison…'**
  String get encryptionWaitingForSas;

  /// No description provided for @encryptionDone.
  ///
  /// In en, this message translates to:
  /// **'Encryption Setup Complete!'**
  String get encryptionDone;

  /// No description provided for @encryptionVerificationDone.
  ///
  /// In en, this message translates to:
  /// **'Verification Complete!'**
  String get encryptionVerificationDone;

  /// No description provided for @encryptionVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get encryptionVerificationFailed;
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
      'that was used.');
}
