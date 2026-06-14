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

import 'dart:async' show Future;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

class _Licenses {
  _Licenses(
      {required this.name, required this.assetName, this.licenseText = ''});
  final String name;
  final String assetName;
  late String licenseText;
}

// ignore: unused_element
Future<_Licenses> _createLicense(String name, String assetName) async {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView.builder(
        itemCount: _usedLicenses.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              title: Text(_usedLicenses[index].name),
            ),
          );
        },
      ),
    );
  }
}
