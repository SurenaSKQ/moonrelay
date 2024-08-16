import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;

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
    return mt.Scaffold(
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(),
            clipBehavior: Clip.antiAlias,
            width: 420,
            child: mainView,
          ),
          const Divider(
            direction: Axis.vertical,
          ),
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
