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
}
