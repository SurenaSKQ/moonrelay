import 'package:flutter/material.dart';

// FIXME - This whole thing should go inside the settings system.
class MoonrelayAppTheme extends ChangeNotifier {
  TextDirection _textDirection = TextDirection.ltr;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection direction) {
    _textDirection = direction;
    notifyListeners();
  }
}

class ThemeFonts {
  // Font settings
  final String fontFamily = 'Rubik';
  final double baseFontSize = 16.0; // Base font size

  // Font sizes based on the base font size
  double get titleFontSize => baseFontSize * 1.5;
  double get subtitleFontSize => baseFontSize * 1.2;
  double get bodyTextFontSize => baseFontSize;
}
