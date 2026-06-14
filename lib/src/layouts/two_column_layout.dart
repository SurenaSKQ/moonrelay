import 'package:flutter/material.dart';

/// Deprecated — replaced by [DashboardLayout].
///
/// The new layout supports hide/show toggles, multiple sidebars, responsive
/// breakpoints via [LayoutBuilder], and drag-to-resize handles.
@Deprecated('Use DashboardLayout from dashboard_layout.dart instead.')
class TwoColumnLayout extends StatelessWidget {
  final Widget mainView;
  final Widget sideView;

  const TwoColumnLayout({
    super.key,
    required this.mainView,
    required this.sideView,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(),
            clipBehavior: Clip.antiAlias,
            width: 420,
            child: mainView,
          ),
          const VerticalDivider(),
          Expanded(
            child: ClipRRect(
              child: sideView,
            ),
          ),
        ],
      ),
    );
  }
}
