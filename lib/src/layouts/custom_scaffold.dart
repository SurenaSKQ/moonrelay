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

import 'package:flutter/material.dart';

class CustomScaffold extends StatefulWidget {
  const CustomScaffold({
    super.key,
    this.topBar,
    this.content = const SizedBox.expand(),
    this.bottomBar,
    this.padding,
    this.backgroundColor,
    this.backgroundDecoration,
    this.avoidBottomInset = true,
  });

  final Widget? topBar;
  final Widget content;
  final Widget? bottomBar;
  final Color? backgroundColor;

  /// This will override the backgroundColor property if both are set.
  final Decoration? backgroundDecoration;

  final EdgeInsets? padding;

  final bool avoidBottomInset;

  @override
  State<CustomScaffold> createState() => _CustomScaffoldState();
}

class _CustomScaffoldState extends State<CustomScaffold> {
  final _bucket = PageStorageBucket();
  @override
  Widget build(BuildContext context) {
    return PageStorage(
      bucket: _bucket,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: widget.avoidBottomInset
              ? MediaQuery.viewInsetsOf(context).bottom
              : 0.0,
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: widget.padding,
                color: (widget.backgroundDecoration != null)
                    ? null
                    : widget.backgroundColor,
                decoration: widget.backgroundDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.topBar != null) widget.topBar!,
                    Expanded(child: widget.content)
                  ],
                ),
              ),
            ),
            if (widget.bottomBar != null) widget.bottomBar!,
          ],
        ),
      ),
    );
  }
}
