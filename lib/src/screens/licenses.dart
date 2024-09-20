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

import 'dart:async' show Future;
import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fluent_ui/fluent_ui.dart';

class _Licenses {
  _Licenses(
      {required this.name, required this.assetName, this.licenseText = ''});
  final String name;
  final String assetName;
  late String licenseText;
}

// ignore: unused_element
Future<_Licenses> _createLicense(name, assetName) async {
  String licenseTxt = await rootBundle.loadString('assets/$assetName');
  return _Licenses(name: name, assetName: assetName, licenseText: licenseTxt);
}

class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});
  static const routeName = '/licenses';

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  final List<_Licenses> _usedLicenses = [
    _Licenses(
        name: "GNU GPL v3",
        assetName: "gpl-v3.0.txt",
        licenseText: "to be added"),
    _Licenses(
        name: "GNU Affero GPL v3",
        assetName: "gpl-v3.0.txt",
        licenseText: "to be added"),
    _Licenses(name: "MIT License", assetName: "", licenseText: "to be added"),
  ];
  @override
  Widget build(BuildContext context) {
    return BlurryContainer.expand(
      child: ScaffoldPage(
          header: IconButton(
            icon: const Icon(FluentIcons.back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          content: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                  child: ListView.builder(
                      itemCount: _usedLicenses.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Expander(
                            header: Text(_usedLicenses[index].name),
                            content: SizedBox(
                              height: 300,
                              child: Text(_usedLicenses[index].licenseText),
                            ),
                          ),
                        );
                      }))
            ],
          )),
    );
  }
}
