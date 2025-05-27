// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.

import 'package:azhi_main/src/screens/user_profile.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:azhi_main/src/helpers/show_error_infobar.dart';

class ProfileDelegate extends StatelessWidget {
  const ProfileDelegate({super.key, required this.userid});
  final String? userid;

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);
    if (userid == null) {
      log.e(
        "Profile page called with null user ID!",
        stackTrace: StackTrace.current,
        time: DateTime.now(),
      );
      showErrorInfobar(
          context,
          "The User's ID could not be understood (userid==null)",
          "Please try again later , or report a bug to our project");
      return const SizedBox.shrink();
    } else {
      return ProfilePage(client: client, userID: userid!);
    }
  }
}
