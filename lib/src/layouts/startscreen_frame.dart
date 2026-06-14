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

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class StartscreenFrame extends StatefulWidget {
  const StartscreenFrame({
    super.key,
    required this.child,
    required this.shellContext,
  });

  final Widget child;
  final BuildContext? shellContext;
  @override
  State<StartscreenFrame> createState() => _StartscreenFrameState();
}

class _StartscreenFrameState extends State<StartscreenFrame>
    with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        title: Text(
          AppLocalizations.of(context)!.appTitle,
          style: const TextStyle(
            fontFamily: 'Rubik',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: widget.child,
    );
  }
}
