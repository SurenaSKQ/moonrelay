// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appLicenseNotice =>
      'This application is provided to you under the GNU Affero General Public License version 3.0 or higher. If you have not recieved the license alognside the program, please consult the moonrelay Website for more information.';

  @override
  String get appTitle => 'MOONRELAY';

  @override
  String get areYouSureExit => 'Are you sure you want to exit the application?';

  @override
  String get author => 'Surena Karimpour Ghannadi';

  @override
  String get chatBoxSendMessage => 'Send a message!';

  @override
  String get confirmClose => 'Confirm Exit';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get directMessages => 'Direct Messages';

  @override
  String get error => 'Error!';

  @override
  String get home => 'Home';

  @override
  String get homeserverText => 'Homeserver';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get loginButton => 'Login';

  @override
  String get noOrCancellation => 'No';

  @override
  String get ownProfileDescriptor => 'Your Profile';

  @override
  String get passwordText => 'Password';

  @override
  String get privacyPolicy => 'Privacy and Your Data';

  @override
  String get projectName => 'Moonrelay';

  @override
  String get thirdPartyLicense => 'Licenses';

  @override
  String get usernameText => 'Username';

  @override
  String userProfilePageBanner(String username) {
    return '$username\'s Profile';
  }

  @override
  String get warning => 'Warning!';

  @override
  String get yesOrAffirmitive => 'Yes';

  @override
  String get chatBoxAttach => 'Attach file';

  @override
  String get chatBoxSend => 'Send';

  @override
  String get chatBoxExpand => 'Expand editor';

  @override
  String get chatBoxCollapse => 'Collapse';

  @override
  String chatBoxReplyingTo(String sender) {
    return 'Replying to $sender';
  }

  @override
  String get chatBoxCancelReply => 'Cancel reply';

  @override
  String get loading => 'Loading…';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get encryptionSecurity => 'Encryption & Security';

  @override
  String get encryptionSetupTitle => 'Encryption Setup';

  @override
  String get encryptionCrossSigning => 'Cross-Signing';

  @override
  String get encryptionCrossSigningActive => 'Cross-signing is active';

  @override
  String get encryptionCrossSigningInactive => 'Cross-signing is not set up';

  @override
  String get encryptionDeviceVerified => 'This device is verified';

  @override
  String get encryptionDeviceNotVerified => 'This device is not verified';

  @override
  String get encryptionBootstrap => 'Set Up Encryption';

  @override
  String get encryptionReBootstrap => 'Re-run Setup';

  @override
  String get encryptionDevices => 'Devices';

  @override
  String get encryptionDevicesLower => 'devices';

  @override
  String get encryptionManageDevices => 'Manage Devices';

  @override
  String get encryptionNoDevices => 'No devices found';

  @override
  String get encryptionDevice => 'Device';

  @override
  String get encryptionThisDevice => 'This device';

  @override
  String get encryptionDeleteDevice => 'Delete Device';

  @override
  String get encryptionDeleteDeviceConfirm => 'Are you sure you want to delete';

  @override
  String get encryptionDeviceDeleted => 'Device deleted';

  @override
  String get encryptionMarkAsVerified => 'Mark as Verified';

  @override
  String get encryptionMarkAsUnverified => 'Mark as Unverified';

  @override
  String get encryptionKeyBackup => 'Key Backup';

  @override
  String get encryptionKeyBackupActive => 'Key backup is enabled';

  @override
  String get encryptionKeyBackupInactive => 'Key backup is not enabled';

  @override
  String get encryptionSetupKeyBackup => 'Set Up Key Backup';

  @override
  String get encryptionSetupCrossSigningFirst => 'Set up cross-signing first';

  @override
  String get encryptionVerifiedUsers => 'Verified Users';

  @override
  String get encryptionUnverifiedOwn => 'My unverified devices';

  @override
  String get encryptionUnverifiedOther => 'Unverified other users';

  @override
  String get encryptionVerifyUser => 'Verify User';

  @override
  String get encryptionUserVerified => 'This user is verified';

  @override
  String get encryptionUserNotVerified => 'This user is not verified';

  @override
  String get encryptionVerify => 'Verify';

  @override
  String get encryptionNoKeyInfo => 'No key information';

  @override
  String get encryptionEnabledTitle => 'Encrypted';

  @override
  String get encryptionNotEnabledTitle => 'Not Encrypted';

  @override
  String get encryptionStatusInfo => 'End-to-end encryption status';

  @override
  String get encryptionDecryptionFailed => 'Decryption failed';

  @override
  String get encryptionRequestKeys => 'Request keys';

  @override
  String get encryptionKeysRequested => 'Key request sent to other devices';

  @override
  String get encryptionUnsupported =>
      'Encryption is not supported in this build';

  @override
  String get encryptionSetupCrossSigning => 'Set Up Cross-Signing';

  @override
  String get encryptionSetupCrossSigningDesc =>
      'Cross-signing allows you to verify other users and devices. This will create signing keys that are stored in your encrypted secret storage.';

  @override
  String get encryptionSetupAllKeys => 'Set Up All Keys';

  @override
  String get encryptionSkipKeySetup => 'Skip Key Setup';

  @override
  String get encryptionExistingSsssFound =>
      'Existing encrypted secrets storage found';

  @override
  String get encryptionWipeExisting => 'Wipe and Start Fresh';

  @override
  String get encryptionKeepExisting => 'Keep Existing';

  @override
  String get encryptionUseExistingSsss => 'Use Existing Secret Storage';

  @override
  String get encryptionBadSsss =>
      'Some secrets could not be read. Continue anyway?';

  @override
  String get encryptionContinueAnyway => 'Continue Anyway';

  @override
  String get encryptionUnlockSsss => 'Unlock Existing Secrets';

  @override
  String get encryptionUnlockDescription =>
      'Enter the passphrase or recovery key for your existing secret storage.';

  @override
  String get encryptionEnterRecoveryKey => 'Enter Recovery Key';

  @override
  String get encryptionPassphraseOrKey => 'Passphrase or Recovery Key';

  @override
  String get encryptionUnlock => 'Unlock';

  @override
  String get encryptionCouldNotUnlock =>
      'Could not unlock with the provided value';

  @override
  String get encryptionCreatePassphrase => 'Create a Recovery Passphrase';

  @override
  String get encryptionSetPassphrase => 'Set Passphrase';

  @override
  String get encryptionUnlocking => 'Unlocking…';

  @override
  String get encryptionCrossSigningExists => 'Cross-signing is already set up';

  @override
  String get encryptionRecreateKeys => 'Re-create Keys';

  @override
  String get encryptionKeepKeys => 'Keep Existing Keys';

  @override
  String get encryptionBackupExists => 'Online key backup already exists';

  @override
  String get encryptionRecreateBackup => 'Re-create Backup';

  @override
  String get encryptionKeepBackup => 'Keep Existing Backup';

  @override
  String get encryptionSetupBackup => 'Set Up Online Key Backup';

  @override
  String get encryptionSetupBackupDesc =>
      'An encrypted backup of your message keys will be stored on the server so you can recover your conversation history on new devices.';

  @override
  String get encryptionEnableBackup => 'Enable Backup';

  @override
  String get encryptionSkipBackup => 'Skip';

  @override
  String get encryptionVerifyUserTitle => 'Verify User';

  @override
  String get encryptionVerificationRequest => 'Verification Request';

  @override
  String get encryptionChooseMethod => 'Choose Verification Method';

  @override
  String get encryptionMethodEmoji => 'Emoji / Numbers (SAS)';

  @override
  String get encryptionMethodQr => 'QR Code';

  @override
  String get encryptionCompareEmojis => 'Compare Emojis';

  @override
  String get encryptionCompareDescription =>
      'Verify that the following emojis (or numbers) match on both devices.';

  @override
  String get encryptionDoTheyMatch => 'Do they match?';

  @override
  String get encryptionTheyMatch => 'They Match';

  @override
  String get encryptionTheyDontMatch => 'They Don\'t Match';

  @override
  String get encryptionWaitingForYou => 'Waiting for you to accept…';

  @override
  String get encryptionWaitingForOther => 'Waiting for the other device…';

  @override
  String get encryptionVerificationWaitingDesc =>
      'The verification request has been sent.';

  @override
  String get encryptionWaitingForSas =>
      'Waiting for the emoji/number comparison…';

  @override
  String get encryptionDone => 'Encryption Setup Complete!';

  @override
  String get encryptionVerificationDone => 'Verification Complete!';

  @override
  String get encryptionVerificationFailed => 'Verification Failed';
}
