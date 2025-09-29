import 'package:moonrelay/src/layouts/custom_scaffold.dart';
import 'package:flutter/material.dart';

// TODO Use layoutbuilder instead of all this
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
