// Relative timestamp formatter tests (FR-AC-01, SCR-25 lines 314-326).
//
// Verifies every boundary case from the SCR-25 Relative Timestamp Format
// table. All timestamps are rendered in IST (Asia/Kolkata, UTC+05:30)
// per SRS section 5.9.
//
// The formatter is a pure function: given a `now` (test injection) and
// a `createdAt`, returns the SCR-25 string.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/activity/application/relative_timestamp_formatter.dart';

void main() {
  // Reference instant: 2026-06-08 12:00:00 IST (== 2026-06-08 06:30:00 UTC).
  // The formatter takes `now` as UTC; the test instants are UTC.
  final now = DateTime.utc(2026, 6, 8, 6, 30);

  group('< 1 minute → "Just now"', () {
    test('exactly now', () {
      expect(formatRelativeTimestamp(now: now, createdAt: now), 'Just now');
    });

    test('30 seconds ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(seconds: 30)),
        ),
        'Just now',
      );
    });

    test('null createdAt also "Just now"', () {
      expect(
        formatRelativeTimestamp(now: now, createdAt: null),
        'Just now',
      );
    });

    test('future timestamp clamps to "Just now"', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.add(const Duration(minutes: 5)),
        ),
        'Just now',
      );
    });
  });

  group('1-59 minutes → "X min ago"', () {
    test('1 minute ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
        '1 min ago',
      );
    });

    test('30 minutes ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(minutes: 30)),
        ),
        '30 min ago',
      );
    });

    test('59 minutes ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(minutes: 59)),
        ),
        '59 min ago',
      );
    });
  });

  group('1-23 hours → "X hours ago" (or "1 hour ago")', () {
    test('60 minutes (exactly 1 hour) ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(minutes: 60)),
        ),
        '1 hour ago',
      );
    });

    test('1 hour 30 minutes ago (still rounds down to 1 hour)', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(minutes: 90)),
        ),
        '1 hour ago',
      );
    });

    test('2 hours ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        '2 hours ago',
      );
    });

    test('23 hours ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(hours: 23)),
        ),
        '23 hours ago',
      );
    });
  });

  group('1 day → "Yesterday"', () {
    test('exactly 24 hours ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(hours: 24)),
        ),
        'Yesterday',
      );
    });

    test('36 hours ago is still "Yesterday"', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(hours: 36)),
        ),
        'Yesterday',
      );
    });
  });

  group('2-6 days → "X days ago"', () {
    test('2 days ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        '2 days ago',
      );
    });

    test('6 days ago', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(days: 6)),
        ),
        '6 days ago',
      );
    });
  });

  group('7+ days, same year → "dd MMM"', () {
    test('7 days ago — same year', () {
      // now is 2026-06-08 06:30 UTC == 2026-06-08 12:00 IST.
      // createdAt = now - 7 days = 2026-06-01 06:30 UTC == 2026-06-01 12:00 IST.
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(days: 7)),
        ),
        '01 Jun',
      );
    });

    test('30 days ago — same year', () {
      // createdAt = now - 30 days = 2026-05-09 06:30 UTC == 2026-05-09 12:00 IST.
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: now.subtract(const Duration(days: 30)),
        ),
        '09 May',
      );
    });

    test('IST timezone shifts the displayed day across midnight UTC', () {
      // now is 2026-06-08 06:30 UTC == 2026-06-08 12:00 IST.
      // createdAt 2026-03-13 23:00 UTC == 2026-03-14 04:30 IST → "14 Mar".
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: DateTime.utc(2026, 3, 13, 23),
        ),
        '14 Mar',
      );
    });
  });

  group('Previous year → "dd MMM yyyy"', () {
    test('28 December 2024 (two years prior)', () {
      // 2024-12-28 06:30 UTC == 2024-12-28 12:00 IST → "28 Dec 2024"
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: DateTime.utc(2024, 12, 28, 6, 30),
        ),
        '28 Dec 2024',
      );
    });

    test('1 January 2025 (still previous year vs 2026 now)', () {
      expect(
        formatRelativeTimestamp(
          now: now,
          createdAt: DateTime.utc(2025, 1, 1, 6, 30),
        ),
        '01 Jan 2025',
      );
    });
  });
}
