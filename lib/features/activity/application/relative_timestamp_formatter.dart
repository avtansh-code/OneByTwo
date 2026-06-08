import 'package:intl/intl.dart';

/// IST timezone offset per SRS section 5.9 (UTC+05:30 fixed; no DST).
const Duration _istOffset = Duration(hours: 5, minutes: 30);

/// Formats a UTC [createdAt] timestamp as a relative-time string per
/// the SCR-25 table at `docs/design/06-screen-specs/23-28-settle-activity-profile.md`
/// lines 314-326.
///
/// All wall-clock comparisons (e.g. "is this the same year as now?")
/// are performed in IST (`Asia/Kolkata`) per SRS section 5.9.
///
/// Pure function; [now] is injected for deterministic tests.
///
/// Boundary semantics:
///
/// - `< 1 min`     → `'Just now'`
/// - `1-59 min`    → `'X min ago'`
/// - `1 hour`      → `'1 hour ago'`
/// - `2-23 hours`  → `'X hours ago'`
/// - `1 day`       → `'Yesterday'` (24-47 hours ago inclusive)
/// - `2-6 days`    → `'X days ago'`
/// - `7+ days, same calendar year (in IST)` → `'dd MMM'` (e.g. `'14 Mar'`)
/// - `previous calendar year (in IST)`      → `'dd MMM yyyy'`
///
/// A `null` [createdAt] OR a future [createdAt] both render as
/// `'Just now'` (defensive — clock drift, server-timestamp not yet
/// resolved).
String formatRelativeTimestamp({
  required DateTime now,
  required DateTime? createdAt,
}) {
  if (createdAt == null) return 'Just now';

  final delta = now.difference(createdAt);
  if (delta.isNegative) return 'Just now';

  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inHours < 1) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) {
    final hours = delta.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  if (delta.inDays < 2) return 'Yesterday';
  if (delta.inDays < 7) return '${delta.inDays} days ago';

  // 7+ days: render as IST date.
  final istCreated = _toIst(createdAt);
  final istNow = _toIst(now);

  if (istCreated.year == istNow.year) {
    return DateFormat('dd MMM').format(istCreated);
  }
  return DateFormat('dd MMM yyyy').format(istCreated);
}

/// Returns the IST wall-clock equivalent of a UTC [utc] DateTime. The
/// returned DateTime has a synthetic local representation: do not use
/// it as a UTC instant — only for `.year`, `.month`, `.day` field
/// access in the formatter.
DateTime _toIst(DateTime utc) {
  return utc.add(_istOffset);
}
