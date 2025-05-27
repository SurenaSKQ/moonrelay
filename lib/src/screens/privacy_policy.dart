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

import 'package:azhi_main/src/layouts/azhi_custom_scaffold.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PrivacyPolicyPopupScreen extends StatelessWidget {
  const PrivacyPolicyPopupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AzhiCustomScaffold(
        topBar: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        content: const Padding(
          padding: EdgeInsets.all(18.0),
          child: Text(
            "ChatSpaces app does not transmit any information other than what is necessary for the application's operation. We do not conduct data gathering or telemetry, and we do not operate an advertisement service. \n Any content shared on the Matrix network is outside of the scope of this privacy policy and will reside on Matrix homeservers, and as such is subject to the privacy policies of each respective partner.",
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: 24,
            ),
          ),
        ));
  }
}
