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

  /// Inform the user of the license and how to obtain it.
  ///
  /// In en, this message translates to:
  /// **'This application is provided to you under the GNU Affero General Public License version 3.0 or higher. If you have not received the license alongside the program, please consult the Moonrelay website for more information.'**
  String get appLicenseNotice;

  /// The main application title shown in the window header.
  ///
  /// In en, this message translates to:
  /// **'Moonrelay'**
  String get appTitle;

  /// The brand name of the application.
  ///
  /// In en, this message translates to:
  /// **'Moonrelay'**
  String get projectName;

  /// The application author's name.
  ///
  /// In en, this message translates to:
  /// **'Surena Karimpour Ghannadi'**
  String get author;

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

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @homeserverText.
  ///
  /// In en, this message translates to:
  /// **'Homeserver'**
  String get homeserverText;

  /// No description provided for @confirmClose.
  ///
  /// In en, this message translates to:
  /// **'Confirm Exit'**
  String get confirmClose;

  /// No description provided for @areYouSureExit.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the application?'**
  String get areYouSureExit;

  /// No description provided for @yesOrAffirmitive.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yesOrAffirmitive;

  /// No description provided for @noOrCancellation.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noOrCancellation;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get collapseSidebar;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get expandSidebar;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @closeWindow.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get closeWindow;

  /// No description provided for @showSystemMenu.
  ///
  /// In en, this message translates to:
  /// **'Show system menu'**
  String get showSystemMenu;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @directMessages.
  ///
  /// In en, this message translates to:
  /// **'Direct Messages'**
  String get directMessages;

  /// No description provided for @thirdPartyLicense.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get thirdPartyLicense;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and Your Data'**
  String get privacyPolicy;

  /// Tagline displayed on the welcome screen below the app name.
  ///
  /// In en, this message translates to:
  /// **'The Public Benefit Messenger'**
  String get startupTagline;

  /// Brief description of the app on the welcome screen.
  ///
  /// In en, this message translates to:
  /// **'A secure, decentralised Matrix client focused on professional communication.'**
  String get startupDescription;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @signInDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your existing account or create a new one.'**
  String get signInDescription;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signInWithSso.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Single Sign-On'**
  String get signInWithSso;

  /// No description provided for @welcomeToApp.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Moonrelay'**
  String get welcomeToApp;

  /// No description provided for @syncingYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Syncing your account…'**
  String get syncingYourAccount;

  /// No description provided for @fetchingRooms.
  ///
  /// In en, this message translates to:
  /// **'Fetching your rooms and messages…'**
  String get fetchingRooms;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInTitle;

  /// No description provided for @ssoTitle.
  ///
  /// In en, this message translates to:
  /// **'Single Sign-On'**
  String get ssoTitle;

  /// No description provided for @tokenLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Token Login'**
  String get tokenLoginTitle;

  /// No description provided for @usernameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get usernameOrEmail;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a username'**
  String get usernameHint;

  /// No description provided for @passwordText.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordText;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @ssoUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'SSO Login URL'**
  String get ssoUrlLabel;

  /// No description provided for @ssoStartingHint.
  ///
  /// In en, this message translates to:
  /// **'Click \"Open in Browser\" to start.'**
  String get ssoStartingHint;

  /// No description provided for @tokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Login Token'**
  String get tokenLabel;

  /// No description provided for @tokenHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your login token here…'**
  String get tokenHint;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in Browser'**
  String get openInBrowser;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get preparing;

  /// No description provided for @completeLogin.
  ///
  /// In en, this message translates to:
  /// **'Complete Login'**
  String get completeLogin;

  /// No description provided for @signInWithToken.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Token'**
  String get signInWithToken;

  /// No description provided for @useSsoInstead.
  ///
  /// In en, this message translates to:
  /// **'Use Single Sign-On instead'**
  String get useSsoInstead;

  /// No description provided for @usePasswordInstead.
  ///
  /// In en, this message translates to:
  /// **'Use password instead'**
  String get usePasswordInstead;

  /// No description provided for @useTokenInstead.
  ///
  /// In en, this message translates to:
  /// **'Use login token instead'**
  String get useTokenInstead;

  /// No description provided for @backToPasswordLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to password login'**
  String get backToPasswordLogin;

  /// No description provided for @loginHomeserverTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to homeserver: The server did not respond in time. Please check your connection and try again.'**
  String get loginHomeserverTimeout;

  /// No description provided for @loginHomeserverError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to homeserver: {error}'**
  String loginHomeserverError(String error);

  /// No description provided for @passwordLoginNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This homeserver does not support password login.'**
  String get passwordLoginNotSupported;

  /// No description provided for @ssoNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This homeserver does not support SSO login.'**
  String get ssoNotSupported;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailed(String error);

  /// No description provided for @loginTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Login timed out. The server may be overloaded. Please try again.'**
  String get loginTimedOut;

  /// No description provided for @tokenLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Token login failed: {error}'**
  String tokenLoginFailed(String error);

  /// No description provided for @pleaseEnterToken.
  ///
  /// In en, this message translates to:
  /// **'Please enter a login token.'**
  String get pleaseEnterToken;

  /// No description provided for @pleasePasteToken.
  ///
  /// In en, this message translates to:
  /// **'Please paste the login token from your browser.'**
  String get pleasePasteToken;

  /// No description provided for @couldNotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser. Use the URL above.'**
  String get couldNotOpenBrowser;

  /// No description provided for @ssoWaitingForBrowser.
  ///
  /// In en, this message translates to:
  /// **'Waiting for browser authentication…'**
  String get ssoWaitingForBrowser;

  /// No description provided for @ssoSwitchToManual.
  ///
  /// In en, this message translates to:
  /// **'Switch to manual setup'**
  String get ssoSwitchToManual;

  /// No description provided for @ssoAutomaticFailed.
  ///
  /// In en, this message translates to:
  /// **'Automatic SSO login failed. You can try manually below.'**
  String get ssoAutomaticFailed;

  /// No description provided for @ssoLocalServerError.
  ///
  /// In en, this message translates to:
  /// **'Could not start local server. Trying manual method.'**
  String get ssoLocalServerError;

  /// No description provided for @ssoWaitingForToken.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the login token from your browser…'**
  String get ssoWaitingForToken;

  /// No description provided for @ssoTokenDetected.
  ///
  /// In en, this message translates to:
  /// **'Login token received! Completing sign-in…'**
  String get ssoTokenDetected;

  /// No description provided for @ssoPasteManually.
  ///
  /// In en, this message translates to:
  /// **'Paste token manually'**
  String get ssoPasteManually;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerTitle;

  /// No description provided for @registerHomeserverHint.
  ///
  /// In en, this message translates to:
  /// **'matrix.org'**
  String get registerHomeserverHint;

  /// No description provided for @usernameText.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameText;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service of this homeserver'**
  String get agreeToTerms;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get creatingAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username.'**
  String get usernameRequired;

  /// No description provided for @usernameNoAt.
  ///
  /// In en, this message translates to:
  /// **'Enter just the local part (e.g. \"alice\"), not your full Matrix ID.'**
  String get usernameNoAt;

  /// No description provided for @usernameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters.'**
  String get usernameTooShort;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password.'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @mustAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the Terms of Service.'**
  String get mustAgreeToTerms;

  /// No description provided for @registerHomeserverTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to homeserver: The server did not respond in time. Please check your connection and try again.'**
  String get registerHomeserverTimeout;

  /// No description provided for @registerHomeserverError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to homeserver: {error}'**
  String registerHomeserverError(String error);

  /// No description provided for @registerRequiresAdditionalSteps.
  ///
  /// In en, this message translates to:
  /// **'This homeserver requires additional steps to register (e.g. email verification or CAPTCHA). Please create an account on the homeserver\'s website instead.'**
  String get registerRequiresAdditionalSteps;

  /// No description provided for @registerTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Registration timed out. The server may be overloaded. Please try again.'**
  String get registerTimedOut;

  /// No description provided for @registerFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String registerFailed(String error);

  /// No description provided for @chatBoxSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send a message…'**
  String get chatBoxSendMessage;

  /// No description provided for @chatBoxSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatBoxSend;

  /// No description provided for @chatBoxAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get chatBoxAttach;

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

  /// No description provided for @formatBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get formatBold;

  /// No description provided for @formatItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get formatItalic;

  /// No description provided for @formatStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get formatStrikethrough;

  /// No description provided for @formatInlineCode.
  ///
  /// In en, this message translates to:
  /// **'Inline code'**
  String get formatInlineCode;

  /// No description provided for @formatCodeBlock.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get formatCodeBlock;

  /// No description provided for @formatBlockquote.
  ///
  /// In en, this message translates to:
  /// **'Blockquote'**
  String get formatBlockquote;

  /// No description provided for @formatHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get formatHeading;

  /// No description provided for @formatUnorderedList.
  ///
  /// In en, this message translates to:
  /// **'Unordered list'**
  String get formatUnorderedList;

  /// No description provided for @formatOrderedList.
  ///
  /// In en, this message translates to:
  /// **'Ordered list'**
  String get formatOrderedList;

  /// No description provided for @formatLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get formatLink;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message.'**
  String get sendFailed;

  /// No description provided for @sendTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out.'**
  String get sendTimedOut;

  /// No description provided for @uploadTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Upload timed out.'**
  String get uploadTimedOut;

  /// No description provided for @reactTooltip.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get reactTooltip;

  /// No description provided for @replyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyTooltip;

  /// No description provided for @forwardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forwardTooltip;

  /// No description provided for @detailsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsTooltip;

  /// No description provided for @deleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteTooltip;

  /// No description provided for @messageCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Message copied to clipboard'**
  String get messageCopiedToClipboard;

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get deleteMessage;

  /// No description provided for @areYouSureDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get areYouSureDeleteMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String failedToDelete(String error);

  /// No description provided for @failedToSendReaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reaction: {error}'**
  String failedToSendReaction(String error);

  /// No description provided for @couldNotLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Could not load messages'**
  String get couldNotLoadMessages;

  /// No description provided for @serverMayBeUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The server may be unreachable. Pull down to retry.'**
  String get serverMayBeUnreachable;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get messageDeleted;

  /// No description provided for @unsupportedEvent.
  ///
  /// In en, this message translates to:
  /// **'{sender} has sent an unsupported event of type {type} with messageType {messageType}'**
  String unsupportedEvent(String sender, String type, String messageType);

  /// No description provided for @noTopicSet.
  ///
  /// In en, this message translates to:
  /// **'No topic set'**
  String get noTopicSet;

  /// No description provided for @stateEventCount.
  ///
  /// In en, this message translates to:
  /// **'{count} state events'**
  String stateEventCount(int count);

  /// No description provided for @roomInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Room Info'**
  String get roomInfoTitle;

  /// No description provided for @copyRoomIdTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy Room ID'**
  String get copyRoomIdTooltip;

  /// No description provided for @actionsSection.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsSection;

  /// No description provided for @leaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave Room'**
  String get leaveRoom;

  /// No description provided for @leaveRoomDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove yourself from this room'**
  String get leaveRoomDescription;

  /// No description provided for @copyRoomId.
  ///
  /// In en, this message translates to:
  /// **'Copy Room ID'**
  String get copyRoomId;

  /// No description provided for @detailsSection.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsSection;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @encryptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get encryptionLabel;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @createdLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdLabel;

  /// No description provided for @endToEndEncrypted.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get endToEndEncrypted;

  /// No description provided for @notEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Not encrypted'**
  String get notEncrypted;

  /// No description provided for @securitySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securitySection;

  /// No description provided for @notEnabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get notEnabled;

  /// No description provided for @membersSection.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersSection;

  /// No description provided for @directMessage.
  ///
  /// In en, this message translates to:
  /// **'Direct Message'**
  String get directMessage;

  /// No description provided for @spaceType.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get spaceType;

  /// No description provided for @publicRoom.
  ///
  /// In en, this message translates to:
  /// **'Public Room'**
  String get publicRoom;

  /// No description provided for @privateRoom.
  ///
  /// In en, this message translates to:
  /// **'Private Room'**
  String get privateRoom;

  /// No description provided for @unknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownDate;

  /// No description provided for @leaveRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Room'**
  String get leaveRoomTitle;

  /// No description provided for @leaveRoomConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave \"{roomName}\"?'**
  String leaveRoomConfirm(String roomName);

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @failedToLeaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave room: {error}'**
  String failedToLeaveRoom(String error);

  /// No description provided for @roomIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Room ID copied to clipboard'**
  String get roomIdCopied;

  /// No description provided for @showAllMembers.
  ///
  /// In en, this message translates to:
  /// **'Show all members ({count})'**
  String showAllMembers(int count);

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get viewProfile;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get sendMessage;

  /// No description provided for @couldNotOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Could not open chat: {error}'**
  String couldNotOpenChat(String error);

  /// No description provided for @userIsVerified.
  ///
  /// In en, this message translates to:
  /// **'User is verified'**
  String get userIsVerified;

  /// No description provided for @userIsNotVerified.
  ///
  /// In en, this message translates to:
  /// **'User is not verified'**
  String get userIsNotVerified;

  /// No description provided for @adminBadge.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminBadge;

  /// No description provided for @moderatorBadge.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get moderatorBadge;

  /// No description provided for @bannedBadge.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get bannedBadge;

  /// No description provided for @invitedBadge.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get invitedBadge;

  /// No description provided for @knockingBadge.
  ///
  /// In en, this message translates to:
  /// **'Knocking'**
  String get knockingBadge;

  /// No description provided for @leftBadge.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftBadge;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'Members ({count})'**
  String membersCount(int count);

  /// No description provided for @searchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search members…'**
  String get searchMembers;

  /// No description provided for @noMembersMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No members match your search'**
  String get noMembersMatchSearch;

  /// No description provided for @noMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found'**
  String get noMembersFound;

  /// No description provided for @couldNotStartChatTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not start chat: The server did not respond in time.'**
  String get couldNotStartChatTimeout;

  /// No description provided for @couldNotStartChat.
  ///
  /// In en, this message translates to:
  /// **'Could not start chat: {error}'**
  String couldNotStartChat(String error);

  /// No description provided for @messageDetails.
  ///
  /// In en, this message translates to:
  /// **'Message Details'**
  String get messageDetails;

  /// No description provided for @senderSection.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get senderSection;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @userIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userIdLabel;

  /// No description provided for @timestampsSection.
  ///
  /// In en, this message translates to:
  /// **'Timestamps'**
  String get timestampsSection;

  /// No description provided for @sentAt.
  ///
  /// In en, this message translates to:
  /// **'Sent at'**
  String get sentAt;

  /// No description provided for @eventInfo.
  ///
  /// In en, this message translates to:
  /// **'Event Info'**
  String get eventInfo;

  /// No description provided for @eventType.
  ///
  /// In en, this message translates to:
  /// **'Event type'**
  String get eventType;

  /// No description provided for @eventId.
  ///
  /// In en, this message translates to:
  /// **'Event ID'**
  String get eventId;

  /// No description provided for @roomId.
  ///
  /// In en, this message translates to:
  /// **'Room ID'**
  String get roomId;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @redactedStatus.
  ///
  /// In en, this message translates to:
  /// **'Redacted (deleted)'**
  String get redactedStatus;

  /// No description provided for @activeStatus.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeStatus;

  /// No description provided for @relationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationshipLabel;

  /// No description provided for @relatedEventId.
  ///
  /// In en, this message translates to:
  /// **'Related event ID'**
  String get relatedEventId;

  /// No description provided for @replyToEventId.
  ///
  /// In en, this message translates to:
  /// **'Reply to event ID'**
  String get replyToEventId;

  /// No description provided for @rawContent.
  ///
  /// In en, this message translates to:
  /// **'Raw Content'**
  String get rawContent;

  /// No description provided for @joinRoomInstructions.
  ///
  /// In en, this message translates to:
  /// **'Search for the room you wish to join:'**
  String get joinRoomInstructions;

  /// No description provided for @roomIdOrAlias.
  ///
  /// In en, this message translates to:
  /// **'Room ID or Alias'**
  String get roomIdOrAlias;

  /// No description provided for @serverInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the server to join through:'**
  String get serverInstructions;

  /// No description provided for @serverOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'If left empty, your own homeserver will be used.'**
  String get serverOptionalHint;

  /// No description provided for @serverLabel.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverLabel;

  /// No description provided for @joining.
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get joining;

  /// No description provided for @addRoom.
  ///
  /// In en, this message translates to:
  /// **'Add Room'**
  String get addRoom;

  /// No description provided for @joiningTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Joining room timed out. The server may be unreachable.'**
  String get joiningTimedOut;

  /// No description provided for @couldNotJoinRoom.
  ///
  /// In en, this message translates to:
  /// **'Could not join room: {error}'**
  String couldNotJoinRoom(String error);

  /// No description provided for @createNewRoom.
  ///
  /// In en, this message translates to:
  /// **'Create New Room'**
  String get createNewRoom;

  /// No description provided for @createRoom.
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoom;

  /// No description provided for @creatingRoomTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Creating room timed out. The server may be unreachable.'**
  String get creatingRoomTimedOut;

  /// No description provided for @couldNotCreateRoom.
  ///
  /// In en, this message translates to:
  /// **'Could not create room: {error}'**
  String couldNotCreateRoom(String error);

  /// No description provided for @loadingRooms.
  ///
  /// In en, this message translates to:
  /// **'Loading rooms…'**
  String get loadingRooms;

  /// No description provided for @noRoomsYet.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet'**
  String get noRoomsYet;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get noMessages;

  /// No description provided for @couldNotJoinRoomTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not join room: The server did not respond in time.'**
  String get couldNotJoinRoomTimeout;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @manageAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage your connected Matrix accounts'**
  String get manageAccounts;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @customizeExperience.
  ///
  /// In en, this message translates to:
  /// **'Customize your experience'**
  String get customizeExperience;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @controlLookAndFeel.
  ///
  /// In en, this message translates to:
  /// **'Control the look and feel of the app'**
  String get controlLookAndFeel;

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @customizeLayout.
  ///
  /// In en, this message translates to:
  /// **'Customize the arrangement of UI panels'**
  String get customizeLayout;

  /// No description provided for @encryptionAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Encryption & Security'**
  String get encryptionAndSecurity;

  /// No description provided for @chatSettings.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatSettings;

  /// No description provided for @timelineAndMessages.
  ///
  /// In en, this message translates to:
  /// **'Timeline and message display options'**
  String get timelineAndMessages;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectCategory;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @colourTheme.
  ///
  /// In en, this message translates to:
  /// **'Colour theme'**
  String get colourTheme;

  /// No description provided for @useSystemTitlebar.
  ///
  /// In en, this message translates to:
  /// **'Use system titlebar'**
  String get useSystemTitlebar;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @useNativeTitlebar.
  ///
  /// In en, this message translates to:
  /// **'Use the native window title bar instead of the custom one'**
  String get useNativeTitlebar;

  /// No description provided for @chatDisplayType.
  ///
  /// In en, this message translates to:
  /// **'Chat display type'**
  String get chatDisplayType;

  /// No description provided for @leftSidebar.
  ///
  /// In en, this message translates to:
  /// **'Left sidebar'**
  String get leftSidebar;

  /// No description provided for @visible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get visible;

  /// No description provided for @showOrHideLeftSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show or hide the left sidebar'**
  String get showOrHideLeftSidebar;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get content;

  /// No description provided for @widthLabel.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get widthLabel;

  /// No description provided for @rooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get rooms;

  /// No description provided for @spaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get spaces;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @rightSidebar.
  ///
  /// In en, this message translates to:
  /// **'Right sidebar (experimental)'**
  String get rightSidebar;

  /// No description provided for @showOrHideRightSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show or hide the right sidebar (hidden on medium screens)'**
  String get showOrHideRightSidebar;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @roomInfo.
  ///
  /// In en, this message translates to:
  /// **'Room Info'**
  String get roomInfo;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @header.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get header;

  /// No description provided for @reversedHeader.
  ///
  /// In en, this message translates to:
  /// **'Reversed header'**
  String get reversedHeader;

  /// No description provided for @reversedHeaderDescription.
  ///
  /// In en, this message translates to:
  /// **'Window buttons on the left, title on the right'**
  String get reversedHeaderDescription;

  /// No description provided for @stateEventsSection.
  ///
  /// In en, this message translates to:
  /// **'State events'**
  String get stateEventsSection;

  /// No description provided for @showStateEvents.
  ///
  /// In en, this message translates to:
  /// **'Show state events'**
  String get showStateEvents;

  /// No description provided for @showStateEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Display join/leave/room changes in the timeline'**
  String get showStateEventsDescription;

  /// No description provided for @hub.
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get hub;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @ownProfileDescriptor.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get ownProfileDescriptor;

  /// No description provided for @profileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile: {error}'**
  String profileLoadError(String error);

  /// No description provided for @profileLoadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile: The server did not respond in time.'**
  String get profileLoadTimeout;

  /// No description provided for @noDisplayNameSet.
  ///
  /// In en, this message translates to:
  /// **'You have not set a display name!'**
  String get noDisplayNameSet;

  /// No description provided for @profilePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile View'**
  String get profilePageTitle;

  /// No description provided for @userProfilePageBanner.
  ///
  /// In en, this message translates to:
  /// **'{username}\'s Profile'**
  String userProfilePageBanner(String username);

  /// No description provided for @userNoDisplayNameSet.
  ///
  /// In en, this message translates to:
  /// **'The user has not set a display name!'**
  String get userNoDisplayNameSet;

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

  /// No description provided for @encryptionVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get encryptionVerified;

  /// No description provided for @encryptionUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get encryptionUnverified;

  /// No description provided for @encryptionFailedAction.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String encryptionFailedAction(String error);

  /// No description provided for @encryptionUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get encryptionUnknownError;

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get failedToLoadImage;

  /// No description provided for @failedToLoadImageWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image: {error}'**
  String failedToLoadImageWithError(String error);

  /// No description provided for @saveAudio.
  ///
  /// In en, this message translates to:
  /// **'Save audio'**
  String get saveAudio;

  /// No description provided for @audioFileName.
  ///
  /// In en, this message translates to:
  /// **'audio_file'**
  String get audioFileName;

  /// No description provided for @downloadAudio.
  ///
  /// In en, this message translates to:
  /// **'Download audio'**
  String get downloadAudio;

  /// No description provided for @saveVideo.
  ///
  /// In en, this message translates to:
  /// **'Save video'**
  String get saveVideo;

  /// No description provided for @videoFileName.
  ///
  /// In en, this message translates to:
  /// **'video_file'**
  String get videoFileName;

  /// No description provided for @unknownType.
  ///
  /// In en, this message translates to:
  /// **'Unknown type'**
  String get unknownType;

  /// No description provided for @downloadVideo.
  ///
  /// In en, this message translates to:
  /// **'Download video'**
  String get downloadVideo;

  /// No description provided for @selectDownloadTarget.
  ///
  /// In en, this message translates to:
  /// **'Select download target'**
  String get selectDownloadTarget;

  /// Information about an attached file.
  ///
  /// In en, this message translates to:
  /// **'File: {name} of Type: {mimeType} with extension: {ext}'**
  String fileInfo(String name, String mimeType, String ext);

  /// State event: a user joined a room.
  ///
  /// In en, this message translates to:
  /// **'{sender} joined'**
  String stateJoined(String sender);

  /// State event: a user left a room.
  ///
  /// In en, this message translates to:
  /// **'{sender} left'**
  String stateLeft(String sender);

  /// State event: a user was banned.
  ///
  /// In en, this message translates to:
  /// **'{sender} banned {target}'**
  String stateBanned(String sender, String target);

  /// State event: a ban with no target name available.
  ///
  /// In en, this message translates to:
  /// **'{sender} banned someone'**
  String stateBannedSimple(String sender);

  /// State event: a user was invited.
  ///
  /// In en, this message translates to:
  /// **'{sender} invited {user}'**
  String stateInvited(String sender, String user);

  /// State event: a user knocked on a room.
  ///
  /// In en, this message translates to:
  /// **'{sender} knocked'**
  String stateKnocked(String sender);

  /// State event: membership change with unknown state.
  ///
  /// In en, this message translates to:
  /// **'{sender} membership changed: {membership}'**
  String stateMembershipChanged(String sender, String membership);

  /// No description provided for @stateRoomNameChanged.
  ///
  /// In en, this message translates to:
  /// **'Room name changed'**
  String get stateRoomNameChanged;

  /// No description provided for @stateRoomTopicChanged.
  ///
  /// In en, this message translates to:
  /// **'Room topic changed'**
  String get stateRoomTopicChanged;

  /// No description provided for @stateRoomAvatarChanged.
  ///
  /// In en, this message translates to:
  /// **'Room avatar changed'**
  String get stateRoomAvatarChanged;

  /// No description provided for @stateRoomCreated.
  ///
  /// In en, this message translates to:
  /// **'Room created'**
  String get stateRoomCreated;

  /// No description provided for @stateEncryptionEnabled.
  ///
  /// In en, this message translates to:
  /// **'Encryption enabled'**
  String get stateEncryptionEnabled;

  /// No description provided for @statePinnedMessagesChanged.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages changed'**
  String get statePinnedMessagesChanged;

  /// No description provided for @stateMainAddressChanged.
  ///
  /// In en, this message translates to:
  /// **'Main address changed'**
  String get stateMainAddressChanged;

  /// No description provided for @statePowerLevelsChanged.
  ///
  /// In en, this message translates to:
  /// **'Power levels changed'**
  String get statePowerLevelsChanged;

  /// No description provided for @stateRoomUpgraded.
  ///
  /// In en, this message translates to:
  /// **'Room upgraded'**
  String get stateRoomUpgraded;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @themeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (Indigo)'**
  String get themeDefault;

  /// No description provided for @themeOceanBlue.
  ///
  /// In en, this message translates to:
  /// **'Ocean Blue'**
  String get themeOceanBlue;

  /// No description provided for @themeMidnightSlate.
  ///
  /// In en, this message translates to:
  /// **'Midnight Slate'**
  String get themeMidnightSlate;

  /// No description provided for @themeCrimson.
  ///
  /// In en, this message translates to:
  /// **'Crimson'**
  String get themeCrimson;

  /// No description provided for @themeAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get themeAmber;

  /// No description provided for @themeSteel.
  ///
  /// In en, this message translates to:
  /// **'Steel'**
  String get themeSteel;

  /// No description provided for @themeSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get themeSky;

  /// No description provided for @displayModern.
  ///
  /// In en, this message translates to:
  /// **'Modern'**
  String get displayModern;

  /// No description provided for @displayIrc.
  ///
  /// In en, this message translates to:
  /// **'IRC'**
  String get displayIrc;

  /// No description provided for @displayBubbles.
  ///
  /// In en, this message translates to:
  /// **'Bubbles'**
  String get displayBubbles;

  /// No description provided for @paneRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get paneRooms;

  /// No description provided for @paneSpaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get paneSpaces;

  /// No description provided for @paneFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get paneFriends;

  /// No description provided for @paneHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get paneHidden;

  /// No description provided for @paneNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get paneNone;

  /// No description provided for @paneRoomInfo.
  ///
  /// In en, this message translates to:
  /// **'Room Info'**
  String get paneRoomInfo;

  /// No description provided for @paneMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get paneMembers;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @userIDLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userIDLabel;

  /// No description provided for @logoutError.
  ///
  /// In en, this message translates to:
  /// **'Logout error: {error}'**
  String logoutError(String error);

  /// No description provided for @privacyPolicyText.
  ///
  /// In en, this message translates to:
  /// **'Moonrelay does not transmit any information beyond what is necessary for the application\'s operation. We do not collect data, run telemetry, or serve advertisements. Any content shared through the Matrix network falls outside this privacy policy; it resides on Matrix homeservers and is subject to their respective policies.'**
  String get privacyPolicyText;

  /// No description provided for @encryptedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get encryptedTooltip;

  /// No description provided for @notEncryptedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Not encrypted'**
  String get notEncryptedTooltip;

  /// No description provided for @verifiedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedTooltip;

  /// No description provided for @unverifiedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get unverifiedTooltip;

  /// No description provided for @navigationHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navigationHome;

  /// No description provided for @navigationAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get navigationAll;
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
