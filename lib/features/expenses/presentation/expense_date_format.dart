import 'package:intl/intl.dart';

/// Fixed IST offset per SRS section 5.9 (UTC+05:30, no DST).
///
/// Mirrors the established convention (`Duration(hours: 5, minutes: 30)`)
/// used by the Friends transaction surfaces, the home aggregator and the
/// activity formatter, so every Expenses surface labels dates in the SAME
/// timezone regardless of the device clock instead of formatting
/// device-local.
const Duration kExpenseIstOffset = Duration(hours: 5, minutes: 30);

/// Formats [timestamp] as an IST long date, e.g. `24 Jun 2026` — the
/// Expense Detail date (Haldi 22) and the add-expense date label.
///
/// Day-first (`d MMM yyyy`) per the Indian convention; no device-local
/// `DateFormat`, no DST.
String formatExpenseIstDate(DateTime timestamp) =>
    DateFormat('d MMM yyyy').format(timestamp.toUtc().add(kExpenseIstOffset));
