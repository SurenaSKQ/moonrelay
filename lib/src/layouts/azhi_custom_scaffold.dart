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

import 'package:fluent_ui/fluent_ui.dart';

class AzhiCustomScaffold extends StatefulWidget {
  const AzhiCustomScaffold({
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
  State<AzhiCustomScaffold> createState() => _AzhiCustomScaffoldState();
}

class _AzhiCustomScaffoldState extends State<AzhiCustomScaffold> {
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
