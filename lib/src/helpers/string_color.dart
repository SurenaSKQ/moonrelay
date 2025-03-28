import 'package:fluent_ui/fluent_ui.dart';

/// Generates Color from a string.
/// Taken from fluffychat (AGPL license)
extension StringColor on String {
  static final _colorCache = <String, Map<double, Color>>{};

  // This private method calculates a color based on the unicode of the string.
  // It iterates over each character in the string, summing their Unicode code units to derive a base number.
  // The base number is then mapped into a range suitable for HSL (Hue, Saturation, Lightness) color space.
  // An HSLColor object is created with full saturation and the specified lightness, which is then converted to a Color.
  Color _getColorLight(double light) {
    var number = 0.0;
    for (var i = 0; i < length; i++) {
      number += codeUnitAt(i);
    }
    number = (number % 12) * 25.5;
    return HSLColor.fromAHSL(1, number, 1, light).toColor();
  }

  // These getter methods provide different shades of colors based on the string.
  // They check the cache first to see if the color has already been computed for a specific lightness value (0.3, 0.2, 0.7, or 0.4).
  // If not, they compute it using _getColorLight(light) and store it in the cache.

  Color get color {
    _colorCache[this] ??= {};
    return _colorCache[this]![0.35] ??= _getColorLight(0.35);
  }

  Color get darkColor {
    _colorCache[this] ??= {};
    return _colorCache[this]![0.2] ??= _getColorLight(0.2);
  }

  Color get lightColorText {
    _colorCache[this] ??= {};
    return _colorCache[this]![0.7] ??= _getColorLight(0.7);
  }

  Color get lightColorAvatar {
    _colorCache[this] ??= {};
    return _colorCache[this]![0.4] ??= _getColorLight(0.4);
  }
}
