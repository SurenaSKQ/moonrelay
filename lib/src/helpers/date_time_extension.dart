// Credits: This file was originally taken from FluffyChat by Famedly
// It is redistributed with appropriate AGPLv3 license and it's copyright is with it's respective owner.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Provides extra functionality for formatting the time.
extension DateTimeExtension on DateTime {
  bool operator <(DateTime other) {
    return millisecondsSinceEpoch < other.millisecondsSinceEpoch;
  }

  bool operator >(DateTime other) {
    return millisecondsSinceEpoch > other.millisecondsSinceEpoch;
  }

  bool operator >=(DateTime other) {
    return millisecondsSinceEpoch >= other.millisecondsSinceEpoch;
  }

  bool operator <=(DateTime other) {
    return millisecondsSinceEpoch <= other.millisecondsSinceEpoch;
  }

  /// Two message events can belong to the same environment. That means that they
  /// don't need to display the time they were sent because they are close
  /// enaugh.
  static const minutesBetweenEnvironments = 10;

  /// Checks if two DateTimes are close enough to belong to the same
  /// environment.
  bool sameEnvironment(DateTime prevTime) {
    return millisecondsSinceEpoch - prevTime.millisecondsSinceEpoch <
        1000 * 60 * minutesBetweenEnvironments;
  }

  /// Returns a simple time String.
  /// TODO: Add localization
  String localizedTimeOfDay(BuildContext context) {
    if (MediaQuery.of(context).alwaysUse24HourFormat) {
      return '${_z(hour)}:${_z(minute)}';
    } else {
      return '${_z(hour % 12 == 0 ? 12 : hour % 12)}:${_z(minute)} ${hour > 11 ? "pm" : "am"}';
    }
  }

  /// Returns [localizedTimeOfDay()] if the ChatTime is today, the name of the week
  /// day if the ChatTime is this week and a date string else.
  String localizedTimeShort(BuildContext context) {
    final now = DateTime.now();

    final sameYear = now.year == year;

    final sameDay = sameYear && now.month == month && now.day == day;

    final sameWeek = sameYear &&
        !sameDay &&
        now.millisecondsSinceEpoch - millisecondsSinceEpoch <
            1000 * 60 * 60 * 24 * 7;

    if (sameDay) {
      return localizedTimeOfDay(context);
    } else if (sameWeek) {
      return DateFormat.EEEE(Localizations.localeOf(context).languageCode)
          .format(this);
    } else if (sameYear) {
      return ("${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}");
    }
    return ("${year.toString()}-${month.toString().padLeft(2, '0')} ${day.toString().padLeft(2, '0')}");
  }

  /// If the DateTime is today, this returns [localizedTimeOfDay()], if not it also
  /// shows the date.
  /// TODO: Add localization
  String localizedTime(BuildContext context) {
    final now = DateTime.now();

    final sameYear = now.year == year;

    final sameDay = sameYear && now.month == month && now.day == day;

    if (sameDay) return localizedTimeOfDay(context);
    return ("${localizedTimeShort(context)}, ${localizedTimeOfDay(context)}");
  }

  /// Returns a short human-readable relative time string suitable for
  /// "last seen" / "active" labels.
  ///
  /// Examples: "just now", "5m", "2h", "3d", "2w", "Jan 15", "Jan 15, 2023"
  String relativeTimeShort(BuildContext context) {
    final now = DateTime.now();
    final diff = now.millisecondsSinceEpoch - millisecondsSinceEpoch;

    if (diff < 0) return localizedTimeOfDay(context);

    const minute = 60000;
    const hour = 3600000;
    const day = 86400000;
    const week = 604800000;

    final l10n = AppLocalizations.of(context)!;

    if (diff < minute) return l10n.timeJustNow;
    if (diff < hour) return l10n.timeMinutes(diff ~/ minute);
    if (diff < day) return l10n.timeHours(diff ~/ hour);
    if (diff < week) return l10n.timeDays(diff ~/ day);

    // Older than a week  show date.
    final sameYear = now.year == year;
    if (sameYear) {
      return '${_monthAbbr(month)} $day';
    }
    return '${_monthAbbr(month)} $day, $year';
  }

  static String _monthAbbr(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m - 1];
  }

  static String _z(int i) => i < 10 ? '0${i.toString()}' : i.toString();
}
