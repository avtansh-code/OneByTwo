import 'package:intl/intl.dart';

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

  /// Returns a human-readable relative time string.
  ///
  /// Examples:
  /// - `Just now` (< 1 minute ago)
  /// - `5m ago` (< 1 hour ago)
  /// - `3h ago` (< 24 hours ago)
  /// - `Yesterday` (1 day ago, same week)
  /// - `Wed, 25 Dec` (this year)
  /// - `25 Dec 2023` (different year)
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.isNegative) {
      return formatDayMonthYear;
    }

    if (diff.inMinutes < 1) {
      return 'Just now';
    }

    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }

    if (diff.inDays == 1) {
      return 'Yesterday';
    }

    if (year == now.year) {
      return formatDayOfWeek;
    }

    return formatDayMonthYear;
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

  /// Returns a grouping key string for section headers.
  ///
  /// - Today: `'Today'`
  /// - Yesterday: `'Yesterday'`
  /// - Same year: `'December'` (month name)
  /// - Different year: `'December 2023'`
  String get groupKey {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    if (isThisYear) return DateFormat('MMMM').format(this);
    return formatMonthYear;
  }
}
