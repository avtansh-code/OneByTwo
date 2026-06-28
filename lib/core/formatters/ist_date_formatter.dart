import 'package:intl/intl.dart';

/// Fixed IST offset per SRS section 5.9 (UTC+05:30, no DST).
///
/// The single source of truth for India Standard Time display maths, so every
/// surface labels dates in the SAME timezone regardless of the device clock
/// instead of formatting device-local.
const Duration kIstOffset = Duration(hours: 5, minutes: 30);

/// Converts [timestamp] to its IST wall-clock instant (fixed UTC+05:30).
DateTime toIst(DateTime timestamp) => timestamp.toUtc().add(kIstOffset);

/// IST-formatted long date, e.g. `24 Jun 2026` (`dd MMM yyyy`, zero-padded
/// day) — no device-local `DateFormat`, no DST.
String formatIstLongDate(DateTime timestamp) =>
    DateFormat('dd MMM yyyy').format(toIst(timestamp));

/// IST-formatted month + year, e.g. `June 2026` (`MMMM yyyy`) — the
/// Settlement History month-group overline header (SCR-24, Haldi 24). The
/// caller upper-cases it at the render site to honour the overline/kicker
/// type ramp (UPPERCASE applied at the call site).
String formatIstMonthYear(DateTime timestamp) =>
    DateFormat('MMMM yyyy').format(toIst(timestamp));
