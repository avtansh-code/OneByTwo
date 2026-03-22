import 'package:intl/intl.dart';

/// Relative time unit for localization support.
///
/// Callers should map these to localized strings in the presentation layer
/// using `AppLocalizations`. The associated numeric value (for [minutes]
/// and [hours]) is provided via [TimeAgoValue].
enum TimeAgoUnit {
  /// Less than 1 minute ago.
  justNow,

  /// 1–59 minutes ago. See the `value` field of the returned record.
  minutes,

  /// 1–23 hours ago. See the `value` field of the returned record.
  hours,

  /// Exactly 1 calendar day ago.
  yesterday,

  /// A specific date within the current calendar year.
  dateThisYear,

  /// A specific date in a different (or future) year.
  dateOtherYear,
}

/// Structured relative time descriptor for localization.
///
/// * [unit] — selects the appropriate l10n string.
/// * [value] — the numeric count (meaningful for [TimeAgoUnit.minutes]
///   and [TimeAgoUnit.hours]; `0` otherwise).
/// * [date] — the original [DateTime], useful for custom formatting
///   when [unit] is [TimeAgoUnit.dateThisYear] or
///   [TimeAgoUnit.dateOtherYear].
typedef TimeAgoValue = ({TimeAgoUnit unit, int value, DateTime date});

/// Date group key type for localization support.
///
/// Callers should map these to localized section headers in the
/// presentation layer using `AppLocalizations`.
enum GroupKeyType {
  /// Today's date.
  today,

  /// Yesterday's date.
  yesterday,

  /// A month within the current calendar year.
  monthThisYear,

  /// A month in a different calendar year.
  monthOtherYear,
}

/// Structured date group key descriptor for localization.
///
/// * [type] — selects the appropriate l10n string.
/// * [date] — the original [DateTime], useful for formatting month/year.
typedef GroupKeyValue = ({GroupKeyType type, DateTime date});

/// Extensions on [DateTime] for formatting, comparison, and grouping.
///
/// All format methods return locale-aware strings using the `intl` package.
extension DateTimeExtensions on DateTime {
  // ── Formatting ───────────────────────────────────────────────────────

  /// Formats as `dd MMM yyyy` (e.g., `25 Dec 2024`).
  String get formatDayMonthYear => DateFormat('dd MMM yyyy').format(this);

  /// Formats as `dd MMM` (e.g., `25 Dec`).
  String get formatDayMonth => DateFormat('dd MMM').format(this);

  /// Formats as `hh:mm a` (e.g., `02:30 PM`).
  String get formatTime => DateFormat('hh:mm a').format(this);

  /// Formats as `dd MMM yyyy, hh:mm a` (e.g., `25 Dec 2024, 02:30 PM`).
  String get formatFull => DateFormat('dd MMM yyyy, hh:mm a').format(this);

  /// Formats as `EEE, dd MMM` (e.g., `Wed, 25 Dec`).
  String get formatDayOfWeek => DateFormat('EEE, dd MMM').format(this);

  /// Formats as `MMMM yyyy` (e.g., `December 2024`).
  String get formatMonthYear => DateFormat('MMMM yyyy').format(this);

  /// Formats as `yyyy-MM-dd` ISO date string (e.g., `2024-12-25`).
  String get formatIso => DateFormat('yyyy-MM-dd').format(this);

  // ── Relative Formatting ──────────────────────────────────────────────

  /// Returns structured relative time components for localization.
  ///
  /// Prefer this over [timeAgo] when building localized UIs. Map the
  /// returned [TimeAgoUnit] to the appropriate `AppLocalizations` string
  /// in the presentation layer.
  ///
  /// The [TimeAgoValue] record fields:
  /// * `unit` — the time bucket (see [TimeAgoUnit]).
  /// * `value` — numeric count for [TimeAgoUnit.minutes] and
  ///   [TimeAgoUnit.hours]; `0` otherwise.
  /// * `date` — the original [DateTime] for date-range formatting.
  TimeAgoValue get timeAgoValue {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.isNegative) {
      return (unit: TimeAgoUnit.dateOtherYear, value: 0, date: this);
    }

    if (diff.inMinutes < 1) {
      return (unit: TimeAgoUnit.justNow, value: 0, date: this);
    }

    if (diff.inHours < 1) {
      return (unit: TimeAgoUnit.minutes, value: diff.inMinutes, date: this);
    }

    if (diff.inHours < 24) {
      return (unit: TimeAgoUnit.hours, value: diff.inHours, date: this);
    }

    if (diff.inDays == 1) {
      return (unit: TimeAgoUnit.yesterday, value: 0, date: this);
    }

    if (year == now.year) {
      return (unit: TimeAgoUnit.dateThisYear, value: 0, date: this);
    }

    return (unit: TimeAgoUnit.dateOtherYear, value: 0, date: this);
  }

  /// Returns a human-readable relative time string (English fallback).
  ///
  /// For localized output, use [timeAgoValue] instead and map the
  /// [TimeAgoUnit] to the appropriate l10n string in the presentation layer.
  ///
  /// Examples:
  /// - `Just now` (< 1 minute ago)
  /// - `5m ago` (< 1 hour ago)
  /// - `3h ago` (< 24 hours ago)
  /// - `Yesterday` (1 day ago)
  /// - `Wed, 25 Dec` (this year)
  /// - `25 Dec 2023` (different year)
  // TODO(l10n): Migrate callers to use timeAgoValue with localized formatting.
  String get timeAgo {
    final tav = timeAgoValue;
    return switch (tav.unit) {
      TimeAgoUnit.justNow => 'Just now',
      TimeAgoUnit.minutes => '${tav.value}m ago',
      TimeAgoUnit.hours => '${tav.value}h ago',
      TimeAgoUnit.yesterday => 'Yesterday',
      TimeAgoUnit.dateThisYear => tav.date.formatDayOfWeek,
      TimeAgoUnit.dateOtherYear => tav.date.formatDayMonthYear,
    };
  }

  // ── Comparison ───────────────────────────────────────────────────────

  /// Returns `true` if this [DateTime] falls on the same calendar day as [other].
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Returns `true` if this [DateTime] falls on today's date.
  bool get isToday => isSameDay(DateTime.now());

  /// Returns `true` if this [DateTime] falls on yesterday's date.
  bool get isYesterday =>
      isSameDay(DateTime.now().subtract(const Duration(days: 1)));

  /// Returns `true` if this [DateTime] falls within the current calendar year.
  bool get isThisYear => year == DateTime.now().year;

  /// Returns `true` if this [DateTime] falls within the current calendar month.
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  // ── Grouping ─────────────────────────────────────────────────────────

  /// Returns the start of the day (midnight) for this [DateTime].
  ///
  /// Useful for grouping items by date in list views.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Returns the start of the month for this [DateTime].
  ///
  /// Useful for grouping items by month (e.g., monthly expense totals).
  DateTime get startOfMonth => DateTime(year, month);

  /// Returns structured group key components for localization.
  ///
  /// Prefer this over [groupKey] when building localized section headers.
  /// Map the returned [GroupKeyType] to the appropriate `AppLocalizations`
  /// string in the presentation layer.
  GroupKeyValue get groupKeyValue {
    if (isToday) return (type: GroupKeyType.today, date: this);
    if (isYesterday) return (type: GroupKeyType.yesterday, date: this);
    if (isThisYear) return (type: GroupKeyType.monthThisYear, date: this);
    return (type: GroupKeyType.monthOtherYear, date: this);
  }

  /// Returns a grouping key string for section headers (English fallback).
  ///
  /// For localized output, use [groupKeyValue] instead and map the
  /// [GroupKeyType] to the appropriate l10n string in the presentation layer.
  ///
  /// - Today: `'Today'`
  /// - Yesterday: `'Yesterday'`
  /// - Same year: `'December'` (month name)
  /// - Different year: `'December 2023'`
  // TODO(l10n): Migrate callers to use groupKeyValue with localized formatting.
  String get groupKey {
    final gkv = groupKeyValue;
    return switch (gkv.type) {
      GroupKeyType.today => 'Today',
      GroupKeyType.yesterday => 'Yesterday',
      GroupKeyType.monthThisYear => DateFormat('MMMM').format(this),
      GroupKeyType.monthOtherYear => formatMonthYear,
    };
  }
}
