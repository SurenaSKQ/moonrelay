// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get projectName => 'ChatSpaces';

  @override
  String get appTitle => 'ChatSpaces';

  @override
  String get author => 'Surena Karimpour Ghannadi';

  @override
  String get loginButton => 'Login';

  @override
  String get usernameText => 'Username';

  @override
  String get passwordText => 'Password';

  @override
  String get homeserverText => 'Homeserver';

  @override
  String get thirdPartyLicense => 'Licenses';

  @override
  String get privacyPolicy => 'Privacy and Your Data';

  @override
  String get appLicenseNotice =>
      'This application is provided to you under the GNU General Public License version 3.0 or higher. If you have not recieved the license alognside the program, please consult the ChatSpaces Website for more information.';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get warning => 'Warning!';

  @override
  String get error => 'Error!';

  @override
  String get confirmClose => 'Confirm Exit';

  @override
  String get areYouSureExit => 'Are you sure you want to exit the application?';

  @override
  String get yesOrAffirmitive => 'Yes';

  @override
  String get noOrCancellation => 'No';

  @override
  String get home => 'Home';

  @override
  String userProfilePageBanner(Object username) {
    return '$username\'s Profile';
  }

  @override
  String get ownProfileDescriptor => 'Your Profile';

  @override
  String get directMessages => 'Direct Messages';

  @override
  String get chatBoxSendMessage => 'Send a message!';
}
