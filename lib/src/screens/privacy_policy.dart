// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:moonrelay/src/layouts/custom_scaffold.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PrivacyPolicyPopupScreen extends StatelessWidget {
  const PrivacyPolicyPopupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
        topBar: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        content: const Padding(
          padding: EdgeInsets.all(18.0),
          child: Text(
            "Moonrelay app does not transmit any information other than what is necessary for the application's operation. We do not conduct data gathering or telemetry, and we do not operate an advertisement service. \n Any content shared on the Matrix network is outside of the scope of this privacy policy and will reside on Matrix homeservers, and as such is subject to the privacy policies of each respective partner.",
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: 24,
            ),
          ),
        ));
  }
}
