// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:ui';

import 'package:moonrelay/src/helpers/string_color.dart';

/// Use this as a reference color palette. Probably mostly useful for making new themes.
class MoonrelayColorPalette {
  // Black/Grey
  static const Color blackChocolate = Color.fromRGBO(24, 17, 0, 1);
  static const Color blackCoral = Color.fromRGBO(98, 111, 0, 1);
  static const Color ordinaryDarkGrey = Color.fromRGBO(33, 33, 33, 1);
  static const Color ordinaryMediumGrey = Color.fromRGBO(117, 117, 117, 1);
  // Red
  static const Color ordinaryRed = Color.fromRGBO(244, 67, 54, 1);
  static const Color brightMaroon = Color.fromRGBO(195, 33, 72, 1);
  static const Color the90sBrick = Color.fromRGBO(255, 110, 97, 1);
  // Green
  static const Color ordinaryLimeGreen = Color.fromRGBO(205, 220, 57, 1);
  static const Color brunswickGreen = Color.fromRGBO(77, 62, 0, 1);
  static const Color britishRacingGreen = Color.fromRGBO(0, 66, 37, 1);
  // Blue
  static const Color ordinaryBlue = Color.fromRGBO(13, 71, 161, 1);
  static const Color ordinaryOrange = Color.fromRGBO(255, 152, 0, 1);
  // CPG = Color Palette Generator
  static const Color cpgDarkest = Color.fromRGBO(26, 26, 46, 1);
  static const Color cpgDarker = Color.fromRGBO(21, 32, 60, 1);
  static const Color cpgDark = Color.fromRGBO(15, 52, 97, 1);
  static const Color cpgRed = Color.fromRGBO(233, 68, 95, 1);
  static const Color cpgWhite = Color.fromRGBO(250, 250, 250, 1);

  // Colors
  static const Color primaryColor =
      Color(0xFF2A2E31); // Example dark color for primary theme
  static const Color secondaryColor =
      Color(0xFF46494C); // Example darker shade of the primary color
  static const Color corporateDarkColor = Color(0x0020272f);
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
