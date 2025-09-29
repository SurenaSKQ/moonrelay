// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';

// TODO This widget is a hack-job to apply a label to a widget
// Rework it in the future
class Label extends StatelessWidget {
  const Label(
      {super.key, required this.label, required this.child, this.labelStyle});
  final String label;
  final TextStyle? labelStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: labelStyle,
        ),
        child
      ],
    );
  }
}
