// Credits: This file was originally taken from FluffyChat by Famedly
// It is redistributed with appropriate AGPLv3 license and it's copyright is with it's respective owner.

import 'package:flutter/material.dart';

/// Generates Color from a string.
extension StringColor on String {
  /// Bounded LRU cache of `(string, lightness) -> color` lookups.
  ///
  /// The cache used to be unbounded, which leaked memory across very long
  /// sessions in rooms with thousands of unique senders.  The LRU keeps
  /// only the most-recently-used [kMaxColorCacheEntries] entries.
  static final _colorCache = <String, Map<double, Color>>{};
  static final List<String> _colorCacheKeys = [];
  static const int kMaxColorCacheEntries = 512;

  /// Inserts [s] into the LRU at the head of [_colorCacheKeys].
  ///
  /// Evicts the oldest entry if the cache is over capacity.
  static void _touch(String s) {
    final idx = _colorCacheKeys.indexOf(s);
    if (idx != -1) _colorCacheKeys.removeAt(idx);
    _colorCacheKeys.add(s);
    while (_colorCacheKeys.length > kMaxColorCacheEntries) {
      final oldest = _colorCacheKeys.removeAt(0);
      _colorCache.remove(oldest);
    }
  }

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
  // They check the cache first to see if the color has already been computed for a specific lightness value (0.35, 0.2, 0.7, or 0.4).
  // If not, they compute it using _getColorLight(light) and store it in the cache.

  Color get color {
    final bucket = _colorCache[this] ??= <double, Color>{};
    _touch(this);
    return bucket[0.35] ??= _getColorLight(0.35);
  }

  Color get darkColor {
    final bucket = _colorCache[this] ??= <double, Color>{};
    _touch(this);
    return bucket[0.2] ??= _getColorLight(0.2);
  }

  Color get lightColorText {
    final bucket = _colorCache[this] ??= <double, Color>{};
    _touch(this);
    return bucket[0.7] ??= _getColorLight(0.7);
  }

  Color get lightColorAvatar {
    final bucket = _colorCache[this] ??= <double, Color>{};
    _touch(this);
    return bucket[0.4] ??= _getColorLight(0.4);
  }
}
