import 'package:moonrelay/src/helpers/string_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:system_theme/system_theme.dart';

import 'package:fluent_ui/fluent_ui.dart';

enum NavigationIndicators { sticky, end }

// FIXME - This whole thing should go inside the settings system.
class MoonrelayAppTheme extends ChangeNotifier {
  AccentColor? _color;
  AccentColor get color => _color ?? systemAccentColor;
  set color(AccentColor color) {
    _color = color;
    notifyListeners();
  }

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  set mode(ThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }

  PaneDisplayMode _displayMode = PaneDisplayMode.auto;
  PaneDisplayMode get displayMode => _displayMode;
  set displayMode(PaneDisplayMode displayMode) {
    _displayMode = displayMode;
    notifyListeners();
  }

  NavigationIndicators _indicator = NavigationIndicators.sticky;
  NavigationIndicators get indicator => _indicator;
  set indicator(NavigationIndicators indicator) {
    _indicator = indicator;
    notifyListeners();
  }

  WindowEffect _windowEffect = WindowEffect.transparent;
  WindowEffect get windowEffect => _windowEffect;
  set windowEffect(WindowEffect windowEffect) {
    _windowEffect = windowEffect;
    notifyListeners();
  }

  void setEffect(WindowEffect effect, BuildContext context) {
    Window.setEffect(
      effect: effect,
      color: [
        WindowEffect.solid,
        WindowEffect.transparent,
      ].contains(effect)
          ? FluentTheme.of(context).micaBackgroundColor.withOpacity(0.05)
          : Colors.transparent,
      dark: FluentTheme.of(context).brightness.isDark,
    );
  }

  TextDirection _textDirection = TextDirection.ltr;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection direction) {
    _textDirection = direction;
    notifyListeners();
  }

  Locale? _locale;
  Locale? get locale => _locale;
  set locale(Locale? locale) {
    _locale = locale;
    notifyListeners();
  }
}

AccentColor get systemAccentColor {
  if ((defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android) &&
      !kIsWeb) {
    return AccentColor.swatch({
      'darkest': SystemTheme.accentColor.darkest,
      'darker': SystemTheme.accentColor.darker,
      'dark': SystemTheme.accentColor.dark,
      'normal': SystemTheme.accentColor.accent,
      'light': SystemTheme.accentColor.light,
      'lighter': SystemTheme.accentColor.lighter,
      'lightest': SystemTheme.accentColor.lightest,
    });
  }
  return Colors.blue;
}

class ThemeColors {
  // Colors
  static const Color primaryColor =
      Color(0xFF2A2E31); // Example dark color for primary theme
  static const Color secondaryColor =
      Color(0xFF46494C); // Example darker shade of the primary color
  static const corporateDarkColor = Color(0x0020272f);
  static const Color accentColor = Color(0xFF58A6FF); // Example accent color

  // Method to get color for a given string
  Color getColorFromString(String text) {
    return text.color;
  }

  // Method to get dark color for a given string
  Color getDarkColorFromString(String text) {
    return text.darkColor;
  }

  // Method to get light color for text based on a given string
  Color getLightColorTextFromString(String text) {
    return text.lightColorText;
  }

  // Method to get light color for avatar based on a given string
  Color getLightColorAvatarFromString(String text) {
    return text.lightColorAvatar;
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
