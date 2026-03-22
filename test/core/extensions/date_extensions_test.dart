import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/extensions/date_extensions.dart';

void main() {
  group('DateTimeExtensions', () {
    // ── Formatting ──────────────────────────────────────────────────────

    group('formatDayMonthYear', () {
      test('should format as dd MMM yyyy', () {
        final date = DateTime(2024, 12, 25);
        expect(date.formatDayMonthYear, equals('25 Dec 2024'));
      });

      test('should pad single-digit day', () {
        final date = DateTime(2024, 1, 5);
        expect(date.formatDayMonthYear, equals('05 Jan 2024'));
      });
    });

    group('formatDayMonth', () {
      test('should format as dd MMM', () {
        final date = DateTime(2024, 12, 25);
        expect(date.formatDayMonth, equals('25 Dec'));
      });
    });

    group('formatTime', () {
      test('should format as hh:mm a (PM)', () {
        final date = DateTime(2024, 12, 25, 14, 30);
        expect(date.formatTime, equals('02:30 PM'));
      });

      test('should format as hh:mm a (AM)', () {
        final date = DateTime(2024, 12, 25, 9, 5);
        expect(date.formatTime, equals('09:05 AM'));
      });

      test('should format noon correctly', () {
        final date = DateTime(2024, 12, 25, 12, 0);
        expect(date.formatTime, equals('12:00 PM'));
      });

      test('should format midnight correctly', () {
        final date = DateTime(2024, 12, 25, 0, 0);
        expect(date.formatTime, equals('12:00 AM'));
      });
    });

    group('formatFull', () {
      test('should format as dd MMM yyyy, hh:mm a', () {
        final date = DateTime(2024, 12, 25, 14, 30);
        expect(date.formatFull, equals('25 Dec 2024, 02:30 PM'));
      });
    });

    group('formatDayOfWeek', () {
      test('should format as EEE, dd MMM', () {
        final date = DateTime(2024, 12, 25); // Wednesday
        expect(date.formatDayOfWeek, equals('Wed, 25 Dec'));
      });
    });

    group('formatMonthYear', () {
      test('should format as MMMM yyyy', () {
        final date = DateTime(2024, 12, 25);
        expect(date.formatMonthYear, equals('December 2024'));
      });
    });

    group('formatIso', () {
      test('should format as yyyy-MM-dd', () {
        final date = DateTime(2024, 12, 25);
        expect(date.formatIso, equals('2024-12-25'));
      });

      test('should pad single-digit month and day', () {
        final date = DateTime(2024, 1, 5);
        expect(date.formatIso, equals('2024-01-05'));
      });
    });

    // ── Relative Formatting ─────────────────────────────────────────────

    group('timeAgo', () {
      test('should return "Just now" for less than 1 minute ago', () {
        final date = DateTime.now().subtract(const Duration(seconds: 30));
        expect(date.timeAgo, equals('Just now'));
      });

      test('should return "Xm ago" for less than 1 hour ago', () {
        final date = DateTime.now().subtract(const Duration(minutes: 5));
        expect(date.timeAgo, equals('5m ago'));
      });

      test('should return "Xh ago" for less than 24 hours ago', () {
        final date = DateTime.now().subtract(const Duration(hours: 3));
        expect(date.timeAgo, equals('3h ago'));
      });

      test('should return "Yesterday" for exactly 1 day ago', () {
        final date = DateTime.now().subtract(const Duration(days: 1));
        expect(date.timeAgo, equals('Yesterday'));
      });

      test('should return day-month-year for date in different year', () {
        final date = DateTime(2023, 6, 15);
        expect(date.timeAgo, equals('15 Jun 2023'));
      });

      test('should return day-month-year for future date', () {
        final date = DateTime.now().add(const Duration(days: 100));
        expect(date.timeAgo, equals(date.formatDayMonthYear));
      });
    });

    // ── Comparison ──────────────────────────────────────────────────────

    group('isSameDay()', () {
      test('should return true for same calendar day', () {
        final a = DateTime(2024, 12, 25, 10, 30);
        final b = DateTime(2024, 12, 25, 22, 0);
        expect(a.isSameDay(b), isTrue);
      });

      test('should return false for different days', () {
        final a = DateTime(2024, 12, 25);
        final b = DateTime(2024, 12, 26);
        expect(a.isSameDay(b), isFalse);
      });

      test('should return false for same day different month', () {
        final a = DateTime(2024, 11, 25);
        final b = DateTime(2024, 12, 25);
        expect(a.isSameDay(b), isFalse);
      });

      test('should return false for same day different year', () {
        final a = DateTime(2023, 12, 25);
        final b = DateTime(2024, 12, 25);
        expect(a.isSameDay(b), isFalse);
      });

      test('should return true when comparing to itself', () {
        final date = DateTime(2024, 12, 25);
        expect(date.isSameDay(date), isTrue);
      });
    });

    group('isToday', () {
      test('should return true for today', () {
        final today = DateTime.now();
        expect(today.isToday, isTrue);
      });

      test('should return false for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(yesterday.isToday, isFalse);
      });

      test('should return false for tomorrow', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(tomorrow.isToday, isFalse);
      });
    });

    group('isYesterday', () {
      test('should return true for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(yesterday.isYesterday, isTrue);
      });

      test('should return false for today', () {
        expect(DateTime.now().isYesterday, isFalse);
      });

      test('should return false for two days ago', () {
        final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
        expect(twoDaysAgo.isYesterday, isFalse);
      });
    });

    group('isThisYear', () {
      test('should return true for current year', () {
        expect(DateTime.now().isThisYear, isTrue);
      });

      test('should return false for previous year', () {
        final lastYear = DateTime(DateTime.now().year - 1, 6, 15);
        expect(lastYear.isThisYear, isFalse);
      });
    });

    group('isThisMonth', () {
      test('should return true for current month', () {
        expect(DateTime.now().isThisMonth, isTrue);
      });

      test('should return false for previous month', () {
        final now = DateTime.now();
        final lastMonth = DateTime(now.year, now.month - 1, 15);
        expect(lastMonth.isThisMonth, isFalse);
      });

      test('should return false for same month in different year', () {
        final now = DateTime.now();
        final lastYear = DateTime(now.year - 1, now.month, now.day);
        expect(lastYear.isThisMonth, isFalse);
      });
    });

    // ── Grouping ────────────────────────────────────────────────────────

    group('startOfDay', () {
      test('should return midnight of the same day', () {
        final date = DateTime(2024, 12, 25, 14, 30, 45);
        final start = date.startOfDay;

        expect(start.year, equals(2024));
        expect(start.month, equals(12));
        expect(start.day, equals(25));
        expect(start.hour, equals(0));
        expect(start.minute, equals(0));
        expect(start.second, equals(0));
        expect(start.millisecond, equals(0));
      });

      test('should return same value for midnight input', () {
        final midnight = DateTime(2024, 12, 25);
        expect(midnight.startOfDay, equals(midnight));
      });
    });

    group('startOfMonth', () {
      test('should return first day of month at midnight', () {
        final date = DateTime(2024, 12, 25, 14, 30);
        final start = date.startOfMonth;

        expect(start.year, equals(2024));
        expect(start.month, equals(12));
        expect(start.day, equals(1));
        expect(start.hour, equals(0));
        expect(start.minute, equals(0));
      });
    });

    group('groupKey', () {
      test('should return "Today" for today', () {
        final today = DateTime.now();
        expect(today.groupKey, equals('Today'));
      });

      test('should return "Yesterday" for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(yesterday.groupKey, equals('Yesterday'));
      });

      test('should return month name for same year', () {
        // Pick a month that is NOT the current month and NOT yesterday
        final now = DateTime.now();
        // Use a date 60 days ago to safely be in a different month
        final pastDate = now.subtract(const Duration(days: 60));
        // Only check this if the past date is in the same year
        if (pastDate.year == now.year) {
          // The group key should be just the month name
          final expectedMonth = _monthName(pastDate.month);
          expect(pastDate.groupKey, equals(expectedMonth));
        }
      });

      test('should return "Month Year" for different year', () {
        final date = DateTime(2023, 6, 15);
        expect(date.groupKey, equals('June 2023'));
      });
    });
  });
}

/// Helper to get the full month name.
String _monthName(int month) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return months[month - 1];
}
