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

//STUB - This needs to handle much more: Right click menu (event-specific), text copying
class BasicTextEvent extends StatefulWidget {
  const BasicTextEvent({super.key, required this.event});
  final Event event;
  @override
  State<BasicTextEvent> createState() => _BasicTextEventState();
}

class _BasicTextEventState extends State<BasicTextEvent> {
  @override
  Widget build(BuildContext context) {
    return Text(
      widget.event.body,
      style: FluentTheme.of(context).typography.bodyLarge,
    );
  }
}
