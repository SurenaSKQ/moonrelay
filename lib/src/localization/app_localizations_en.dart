// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appLicenseNotice =>
      'This application is provided to you under the GNU Affero General Public License version 3.0 or higher. If you have not received the license alongside the program, please consult the Moonrelay website for more information.';

  @override
  String get appTitle => 'Moonrelay';

  @override
  String get projectName => 'Moonrelay';

  @override
  String get author => 'Surena Karimpour Ghannadi';

  @override
  String get loading => 'Loading…';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get error => 'Error';

  @override
  String get warning => 'Warning';

  @override
  String get unknown => 'Unknown';

  @override
  String get notSet => 'Not set';

  @override
  String get homeserverText => 'Homeserver';

  @override
  String get confirmClose => 'Confirm Exit';

  @override
  String get areYouSureExit => 'Are you sure you want to exit the application?';

  @override
  String get yesOrAffirmitive => 'Yes';

  @override
  String get noOrCancellation => 'No';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restore => 'Restore';

  @override
  String get closeWindow => 'Close window';

  @override
  String get showSystemMenu => 'Show system menu';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get home => 'Home';

  @override
  String get directMessages => 'Direct Messages';

  @override
  String get thirdPartyLicense => 'Licenses';

  @override
  String get privacyPolicy => 'Privacy and Your Data';

  @override
  String get startupTagline => 'The Public Benefit Messenger';

  @override
  String get startupDescription =>
      'A secure, decentralised Matrix client focused on professional communication.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get signInDescription =>
      'Sign in to your existing account or create a new one.';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get signInWithSso => 'Sign in with Single Sign-On';

  @override
  String get welcomeToApp => 'Welcome to Moonrelay';

  @override
  String get syncingYourAccount => 'Syncing your account…';

  @override
  String get fetchingRooms => 'Fetching your rooms and messages…';

  @override
  String get loginButton => 'Sign In';

  @override
  String get signInTitle => 'Sign In';

  @override
  String get ssoTitle => 'Single Sign-On';

  @override
  String get tokenLoginTitle => 'Token Login';

  @override
  String get usernameOrEmail => 'Username or email';

  @override
  String get usernameHint => 'Choose a username';

  @override
  String get passwordText => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get ssoUrlLabel => 'SSO Login URL';

  @override
  String get ssoStartingHint => 'Click \"Open in Browser\" to start.';

  @override
  String get tokenLabel => 'Login Token';

  @override
  String get tokenHint => 'Paste your login token here…';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get openInBrowser => 'Open in Browser';

  @override
  String get preparing => 'Preparing…';

  @override
  String get completeLogin => 'Complete Login';

  @override
  String get signInWithToken => 'Sign in with Token';

  @override
  String get useSsoInstead => 'Use Single Sign-On instead';

  @override
  String get usePasswordInstead => 'Use password instead';

  @override
  String get useTokenInstead => 'Use login token instead';

  @override
  String get backToPasswordLogin => 'Back to password login';

  @override
  String get loginHomeserverTimeout =>
      'Could not connect to homeserver: The server did not respond in time. Please check your connection and try again.';

  @override
  String loginHomeserverError(String error) {
    return 'Could not connect to homeserver: $error';
  }

  @override
  String get passwordLoginNotSupported =>
      'This homeserver does not support password login.';

  @override
  String get ssoNotSupported => 'This homeserver does not support SSO login.';

  @override
  String loginFailed(String error) {
    return 'Login failed: $error';
  }

  @override
  String get loginTimedOut =>
      'Login timed out. The server may be overloaded. Please try again.';

  @override
  String tokenLoginFailed(String error) {
    return 'Token login failed: $error';
  }

  @override
  String get pleaseEnterToken => 'Please enter a login token.';

  @override
  String get pleasePasteToken =>
      'Please paste the login token from your browser.';

  @override
  String get couldNotOpenBrowser =>
      'Could not open browser. Use the URL above.';

  @override
  String get ssoWaitingForBrowser => 'Waiting for browser authentication…';

  @override
  String get ssoSwitchToManual => 'Switch to manual setup';

  @override
  String get ssoAutomaticFailed =>
      'Automatic SSO login failed. You can try manually below.';

  @override
  String get ssoLocalServerError =>
      'Could not start local server. Trying manual method.';

  @override
  String get ssoWaitingForToken =>
      'Waiting for the login token from your browser…';

  @override
  String get ssoTokenDetected => 'Login token received! Completing sign-in…';

  @override
  String get ssoPasteManually => 'Paste token manually';

  @override
  String get registerTitle => 'Create Account';

  @override
  String get registerHomeserverHint => 'matrix.org';

  @override
  String get usernameText => 'Username';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get agreeToTerms =>
      'I agree to the Terms of Service of this homeserver';

  @override
  String get creatingAccount => 'Creating account…';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get usernameRequired => 'Please enter a username.';

  @override
  String get usernameNoAt =>
      'Enter just the local part (e.g. \"alice\"), not your full Matrix ID.';

  @override
  String get usernameTooShort => 'Username must be at least 3 characters.';

  @override
  String get passwordRequired => 'Please enter a password.';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get mustAgreeToTerms => 'You must agree to the Terms of Service.';

  @override
  String get registerHomeserverTimeout =>
      'Could not connect to homeserver: The server did not respond in time. Please check your connection and try again.';

  @override
  String registerHomeserverError(String error) {
    return 'Could not connect to homeserver: $error';
  }

  @override
  String get registerRequiresAdditionalSteps =>
      'This homeserver requires additional steps to register (e.g. email verification or CAPTCHA). Please create an account on the homeserver\'s website instead.';

  @override
  String get registerTimedOut =>
      'Registration timed out. The server may be overloaded. Please try again.';

  @override
  String registerFailed(String error) {
    return 'Registration failed: $error';
  }

  @override
  String get chatBoxSendMessage => 'Send a message…';

  @override
  String get chatBoxSend => 'Send';

  @override
  String get chatBoxAttach => 'Attach file';

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
  String get formatBold => 'Bold';

  @override
  String get formatItalic => 'Italic';

  @override
  String get formatStrikethrough => 'Strikethrough';

  @override
  String get formatInlineCode => 'Inline code';

  @override
  String get formatCodeBlock => 'Code block';

  @override
  String get formatBlockquote => 'Blockquote';

  @override
  String get formatHeading => 'Heading';

  @override
  String get formatUnorderedList => 'Unordered list';

  @override
  String get formatOrderedList => 'Ordered list';

  @override
  String get formatLink => 'Link';

  @override
  String get sendFailed => 'Failed to send message.';

  @override
  String get sendTimedOut => 'The request timed out.';

  @override
  String get uploadTimedOut => 'Upload timed out.';

  @override
  String get reactTooltip => 'React';

  @override
  String get replyTooltip => 'Reply';

  @override
  String get forwardTooltip => 'Forward';

  @override
  String get detailsTooltip => 'Details';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get messageCopiedToClipboard => 'Message copied to clipboard';

  @override
  String get deleteMessage => 'Delete message';

  @override
  String get areYouSureDeleteMessage =>
      'Are you sure you want to delete this message?';

  @override
  String get delete => 'Delete';

  @override
  String failedToDelete(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String failedToSendReaction(String error) {
    return 'Failed to send reaction: $error';
  }

  @override
  String get couldNotLoadMessages => 'Could not load messages';

  @override
  String get serverMayBeUnreachable =>
      'The server may be unreachable. Pull down to retry.';

  @override
  String get messageDeleted => 'Message deleted';

  @override
  String unsupportedEvent(String sender, String type, String messageType) {
    return '$sender has sent an unsupported event of type $type with messageType $messageType';
  }

  @override
  String get noTopicSet => 'No topic set';

  @override
  String stateEventCount(int count) {
    return '$count state events';
  }

  @override
  String get roomInfoTitle => 'Room Info';

  @override
  String get copyRoomIdTooltip => 'Copy Room ID';

  @override
  String get actionsSection => 'Actions';

  @override
  String get leaveRoom => 'Leave Room';

  @override
  String get leaveRoomDescription => 'Remove yourself from this room';

  @override
  String get copyRoomId => 'Copy Room ID';

  @override
  String get detailsSection => 'Details';

  @override
  String get typeLabel => 'Type';

  @override
  String get encryptionLabel => 'Encryption';

  @override
  String get addressLabel => 'Address';

  @override
  String get createdLabel => 'Created';

  @override
  String get endToEndEncrypted => 'End-to-end encrypted';

  @override
  String get notEncrypted => 'Not encrypted';

  @override
  String get securitySection => 'Security';

  @override
  String get notEnabled => 'Not enabled';

  @override
  String get membersSection => 'Members';

  @override
  String get directMessage => 'Direct Message';

  @override
  String get spaceType => 'Space';

  @override
  String get publicRoom => 'Public Room';

  @override
  String get privateRoom => 'Private Room';

  @override
  String get unknownDate => 'Unknown';

  @override
  String get leaveRoomTitle => 'Leave Room';

  @override
  String leaveRoomConfirm(String roomName) {
    return 'Are you sure you want to leave \"$roomName\"?';
  }

  @override
  String get leave => 'Leave';

  @override
  String failedToLeaveRoom(String error) {
    return 'Failed to leave room: $error';
  }

  @override
  String get roomIdCopied => 'Room ID copied to clipboard';

  @override
  String showAllMembers(int count) {
    return 'Show all members ($count)';
  }

  @override
  String get viewProfile => 'View Profile';

  @override
  String get sendMessage => 'Send Message';

  @override
  String couldNotOpenChat(String error) {
    return 'Could not open chat: $error';
  }

  @override
  String get userIsVerified => 'User is verified';

  @override
  String get userIsNotVerified => 'User is not verified';

  @override
  String get adminBadge => 'Admin';

  @override
  String get moderatorBadge => 'Moderator';

  @override
  String get bannedBadge => 'Banned';

  @override
  String get invitedBadge => 'Invited';

  @override
  String get knockingBadge => 'Knocking';

  @override
  String get leftBadge => 'Left';

  @override
  String membersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String get searchMembers => 'Search members…';

  @override
  String get noMembersMatchSearch => 'No members match your search';

  @override
  String get noMembersFound => 'No members found';

  @override
  String get couldNotStartChatTimeout =>
      'Could not start chat: The server did not respond in time.';

  @override
  String couldNotStartChat(String error) {
    return 'Could not start chat: $error';
  }

  @override
  String get messageDetails => 'Message Details';

  @override
  String get senderSection => 'Sender';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get userIdLabel => 'User ID';

  @override
  String get timestampsSection => 'Timestamps';

  @override
  String get sentAt => 'Sent at';

  @override
  String get eventInfo => 'Event Info';

  @override
  String get eventType => 'Event type';

  @override
  String get eventId => 'Event ID';

  @override
  String get roomId => 'Room ID';

  @override
  String get statusLabel => 'Status';

  @override
  String get redactedStatus => 'Redacted (deleted)';

  @override
  String get activeStatus => 'Active';

  @override
  String get relationshipLabel => 'Relationship';

  @override
  String get relatedEventId => 'Related event ID';

  @override
  String get replyToEventId => 'Reply to event ID';

  @override
  String get rawContent => 'Raw Content';

  @override
  String get joinRoomInstructions => 'Search for the room you wish to join:';

  @override
  String get roomIdOrAlias => 'Room ID or Alias';

  @override
  String get serverInstructions => 'Enter the server to join through:';

  @override
  String get serverOptionalHint =>
      'If left empty, your own homeserver will be used.';

  @override
  String get serverLabel => 'Server';

  @override
  String get joining => 'Joining…';

  @override
  String get addRoom => 'Add Room';

  @override
  String get joiningTimedOut =>
      'Joining room timed out. The server may be unreachable.';

  @override
  String couldNotJoinRoom(String error) {
    return 'Could not join room: $error';
  }

  @override
  String get createNewRoom => 'Create New Room';

  @override
  String get createRoom => 'Create Room';

  @override
  String get creatingRoomTimedOut =>
      'Creating room timed out. The server may be unreachable.';

  @override
  String couldNotCreateRoom(String error) {
    return 'Could not create room: $error';
  }

  @override
  String get loadingRooms => 'Loading rooms…';

  @override
  String get noRoomsYet => 'No rooms yet';

  @override
  String get noMessages => 'No messages';

  @override
  String get couldNotJoinRoomTimeout =>
      'Could not join room: The server did not respond in time.';

  @override
  String get accounts => 'Accounts';

  @override
  String get manageAccounts => 'Manage your connected Matrix accounts';

  @override
  String get myProfile => 'My Profile';

  @override
  String get appSettings => 'App Settings';

  @override
  String get customizeExperience => 'Customize your experience';

  @override
  String get appearance => 'Appearance';

  @override
  String get controlLookAndFeel => 'Control the look and feel of the app';

  @override
  String get layout => 'Layout';

  @override
  String get customizeLayout => 'Customize the arrangement of UI panels';

  @override
  String get encryptionAndSecurity => 'Encryption & Security';

  @override
  String get chatSettings => 'Chat';

  @override
  String get timelineAndMessages => 'Timeline and message display options';

  @override
  String get selectCategory => 'Select a category';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get colourTheme => 'Colour theme';

  @override
  String get useSystemTitlebar => 'Use system titlebar';

  @override
  String get enable => 'Enable';

  @override
  String get useNativeTitlebar =>
      'Use the native window title bar instead of the custom one';

  @override
  String get chatDisplayType => 'Chat display type';

  @override
  String get leftSidebar => 'Left sidebar';

  @override
  String get visible => 'Visible';

  @override
  String get showOrHideLeftSidebar => 'Show or hide the left sidebar';

  @override
  String get content => 'Content';

  @override
  String get widthLabel => 'Width';

  @override
  String get rooms => 'Rooms';

  @override
  String get spaces => 'Spaces';

  @override
  String get friends => 'Friends';

  @override
  String get hidden => 'Hidden';

  @override
  String get rightSidebar => 'Right sidebar (experimental)';

  @override
  String get showOrHideRightSidebar =>
      'Show or hide the right sidebar (hidden on medium screens)';

  @override
  String get none => 'None';

  @override
  String get roomInfo => 'Room Info';

  @override
  String get members => 'Members';

  @override
  String get header => 'Header';

  @override
  String get reversedHeader => 'Reversed header';

  @override
  String get reversedHeaderDescription =>
      'Window buttons on the left, title on the right';

  @override
  String get stateEventsSection => 'State events';

  @override
  String get showStateEvents => 'Show state events';

  @override
  String get showStateEventsDescription =>
      'Display join/leave/room changes in the timeline';

  @override
  String get hub => 'Hub';

  @override
  String get logOut => 'Log Out';

  @override
  String get ownProfileDescriptor => 'Your Profile';

  @override
  String profileLoadError(String error) {
    return 'Could not load profile: $error';
  }

  @override
  String get profileLoadTimeout =>
      'Could not load profile: The server did not respond in time.';

  @override
  String get noDisplayNameSet => 'You have not set a display name!';

  @override
  String get profilePageTitle => 'Profile View';

  @override
  String userProfilePageBanner(String username) {
    return '$username\'s Profile';
  }

  @override
  String get userNoDisplayNameSet => 'The user has not set a display name!';

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

  @override
  String get encryptionVerified => 'Verified';

  @override
  String get encryptionUnverified => 'Unverified';

  @override
  String encryptionFailedAction(String error) {
    return 'Failed: $error';
  }

  @override
  String get encryptionUnknownError => 'Unknown error';

  @override
  String get failedToLoadImage => 'Failed to load image';

  @override
  String failedToLoadImageWithError(String error) {
    return 'Failed to load image: $error';
  }

  @override
  String get saveAudio => 'Save audio';

  @override
  String get audioFileName => 'audio_file';

  @override
  String get downloadAudio => 'Download audio';

  @override
  String get saveVideo => 'Save video';

  @override
  String get videoFileName => 'video_file';

  @override
  String get unknownType => 'Unknown type';

  @override
  String get downloadVideo => 'Download video';

  @override
  String get selectDownloadTarget => 'Select download target';

  @override
  String fileInfo(String name, String mimeType, String ext) {
    return 'File: $name of Type: $mimeType with extension: $ext';
  }

  @override
  String stateJoined(String sender) {
    return '$sender joined';
  }

  @override
  String stateLeft(String sender) {
    return '$sender left';
  }

  @override
  String stateBanned(String sender, String target) {
    return '$sender banned $target';
  }

  @override
  String stateBannedSimple(String sender) {
    return '$sender banned someone';
  }

  @override
  String stateInvited(String sender, String user) {
    return '$sender invited $user';
  }

  @override
  String stateKnocked(String sender) {
    return '$sender knocked';
  }

  @override
  String stateMembershipChanged(String sender, String membership) {
    return '$sender membership changed: $membership';
  }

  @override
  String get stateRoomNameChanged => 'Room name changed';

  @override
  String get stateRoomTopicChanged => 'Room topic changed';

  @override
  String get stateRoomAvatarChanged => 'Room avatar changed';

  @override
  String get stateRoomCreated => 'Room created';

  @override
  String get stateEncryptionEnabled => 'Encryption enabled';

  @override
  String get statePinnedMessagesChanged => 'Pinned messages changed';

  @override
  String get stateMainAddressChanged => 'Main address changed';

  @override
  String get statePowerLevelsChanged => 'Power levels changed';

  @override
  String get stateRoomUpgraded => 'Room upgraded';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get themeDefault => 'Default (Indigo)';

  @override
  String get themeOceanBlue => 'Ocean Blue';

  @override
  String get themeMidnightSlate => 'Midnight Slate';

  @override
  String get themeCrimson => 'Crimson';

  @override
  String get themeAmber => 'Amber';

  @override
  String get themeSteel => 'Steel';

  @override
  String get themeSky => 'Sky';

  @override
  String get displayModern => 'Modern';

  @override
  String get displayIrc => 'IRC';

  @override
  String get displayBubbles => 'Bubbles';

  @override
  String get paneRooms => 'Rooms';

  @override
  String get paneSpaces => 'Spaces';

  @override
  String get paneFriends => 'Friends';

  @override
  String get paneHidden => 'Hidden';

  @override
  String get paneNone => 'None';

  @override
  String get paneRoomInfo => 'Room Info';

  @override
  String get paneMembers => 'Members';

  @override
  String get displayName => 'Display Name';

  @override
  String get userIDLabel => 'User ID';

  @override
  String logoutError(String error) {
    return 'Logout error: $error';
  }

  @override
  String get privacyPolicyText =>
      'Moonrelay does not transmit any information beyond what is necessary for the application\'s operation. We do not collect data, run telemetry, or serve advertisements. Any content shared through the Matrix network falls outside this privacy policy; it resides on Matrix homeservers and is subject to their respective policies.';

  @override
  String get encryptedTooltip => 'Encrypted';

  @override
  String get notEncryptedTooltip => 'Not encrypted';

  @override
  String get verifiedTooltip => 'Verified';

  @override
  String get unverifiedTooltip => 'Unverified';

  @override
  String get navigationHome => 'Home';

  @override
  String get navigationAll => 'All';
}
