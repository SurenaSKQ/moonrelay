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

/// A widget that draws a child inside a container that can act as:
/// a) A button : Leave a simple empty function that returns false as 'widgetSelectedLogicHandler'
/// b) A toggle buttom : Implement the logic of the banner being highlighted as the function
/// 'widgetSelectedLogicHandler' -- when this function returns true; the banner will apply 'highlightColor'
/// NOTE: The function ONLY determines the applied color -- onTap function will be EXECUTED UNCONDITIONALLY!
/// The colors supplied will be applied as the color property of the container of widget's child.
/// NOTE: The 'decoration' property specifies the parent of the container; it's properties will not affect
/// the color of the widget which is determined by the dedicated color properties!
/// Rationale for 'widgetSelectedLogicHandler' function:
/// you might want to have some logic that toggles this button on only if a condition happens;
/// probably you want to show a specific screen using this widget and want the widget to be highlighted
/// only if the screen is currently active in your routing structure; and as such a simple
/// toggleButton would be too simplistic.
/// You can make this widget work as a simple toggleButton too; if you write the appropriate function.

class ClickableBannerWidget extends StatefulWidget {
  const ClickableBannerWidget({
    super.key,
    required this.onTap,
    required this.child,
    this.baseColor = Colors.transparent,
    this.activeColor = Colors.grey,
    this.highlightColor = Colors.transparent,
    this.active = true,
    required this.widgetSelectedLogicHandler,
    this.decoration,
    this.internalPadding = const EdgeInsets.fromLTRB(4.25, 5, 4.25, 5),
  });
  final Function onTap;
  final Widget child;
  final Color baseColor;
  final Color activeColor;
  final Color highlightColor;
  final bool active;
  final bool Function() widgetSelectedLogicHandler;
  final Decoration? decoration;
  final EdgeInsetsGeometry internalPadding;

  @override
  State<ClickableBannerWidget> createState() => _ClickableBannerWidgetState();
}

class _ClickableBannerWidgetState extends State<ClickableBannerWidget> {
  bool _active = false;
  bool _selected = false;
  bool _hovered = false;
  Color? _currentColor;

  @override
  void initState() {
    _active = widget.active;
    _hovered = false;
    _selected = false;
    _currentColor = widget.baseColor;
    super.initState();
  }

  @override
  void setState(VoidCallback fn) {
    _selected ? _currentColor = widget.activeColor : null;
    _hovered ? _currentColor = widget.highlightColor : null;
    super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        _active ? setState(() => _hovered = true) : null;
      },
      onExit: (event) => _active ? setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: () {
          if (_active) {
            setState(
              () {
                widget.widgetSelectedLogicHandler()
                    ? _selected = true
                    : _selected = false;
              },
            );
            widget.onTap;
          }
        },
        child: Container(
          decoration: widget.decoration,
          child: Container(
            color: _currentColor,
            padding: widget.internalPadding,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
