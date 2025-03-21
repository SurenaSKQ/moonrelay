// Copyright (C) 2025 Surena Karimpour Ghannadi
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

import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';

class AzhiChatEvent extends StatefulWidget {
  const AzhiChatEvent({super.key, required this.event});
  final Event event;
  @override
  State<AzhiChatEvent> createState() => _AzhiChatEventState();
}

class _AzhiChatEventState extends State<AzhiChatEvent> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: FluentTheme.of(context).accentColor,
          width: 1,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
        color: FluentTheme.of(context).acrylicBackgroundColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          widget.event.body,
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
        ),
      ),
    );
  }
}
