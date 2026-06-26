import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

/// Reusable rupee-amount input that emits **paise** integers (Option E
/// extract per Architect Notes §2.8). The companion `OBTRupeeText` and
/// other read-side widgets in the design-system catalogue render paise
/// via `formatInrFromPaise()`; this widget is the write-side dual,
/// converting user rupee text into integer paise at the controller
/// boundary.
///
/// Contract (FR-EX-01, FR-EX-04, FR-EX-09, Invariant 1):
///
/// - Emits `int` paise via [onChanged] on every accepted keystroke.
///   Never emits a `double`. Never emits a rupee value.
/// - Refuses non-numeric input.
/// - Refuses negative input (no minus sign accepted).
/// - Refuses entries that would exceed [_kMaxPaise]
///   (`99,99,999.99` per AC-2 — `9,99,99,999` paise = `999,999,999`);
///   over-cap keystrokes are silently
///   rejected and the previous value is preserved.
/// - Allows at most two digits after the decimal point.
/// - Allows at most one decimal point.
/// - Displays the user's input with Indian-numbering separators on
///   the rupee component (`1,23,456.78`).
/// - Renders the `₹` prefix as a non-editable visual.
class OBTAmountInput extends StatefulWidget {
  /// Creates an [OBTAmountInput].
  const OBTAmountInput({
    required this.onChanged,
    super.key,
    this.initialAmountPaise,
    this.autoFocus = true,
    this.errorText,
    this.enabled = true,
  });

  /// Pre-filled amount in paise (for edit flows); `null` shows an
  /// empty input.
  final int? initialAmountPaise;

  /// Fires on every accepted change with the current value in
  /// **paise** (`int`). Never a `double`; never a rupee value.
  final ValueChanged<int> onChanged;

  /// Whether the keyboard opens immediately when the input mounts.
  final bool autoFocus;

  /// Inline validation message shown below the field; supplied by the
  /// controller (the widget is presentation-only).
  final String? errorText;

  /// When `false`, the field is greyed out and ignores input.
  final bool enabled;

  @override
  State<OBTAmountInput> createState() => _OBTAmountInputState();
}

const int _kMaxPaise = 999999999; // AC-2: ₹99,99,999.99 (9,99,99,999 paise)

class _OBTAmountInputState extends State<OBTAmountInput> {
  late final TextEditingController _controller;
  late final _RupeeInputFormatter _formatter;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmountPaise;
    final initialText = initial == null || initial == 0
        ? ''
        : _formatPaiseAsEditableText(initial);
    _controller = TextEditingController(text: initialText);
    _formatter = _RupeeInputFormatter(maxPaise: _kMaxPaise);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final paise = _paiseFromText(text);
    widget.onChanged(paise);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = OBTText.amount(context);
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      autofocus: widget.autoFocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_formatter],
      onChanged: _onTextChanged,
      style: amountStyle,
      decoration: InputDecoration(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppTheme.radiusChipInput),
          ),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            '₹',
            style: amountStyle.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 32),
        hintText: '0.00',
        errorText: widget.errorText,
      ),
    );
  }
}

/// Formats a paise integer as an editable text representation (e.g.
/// 1234 → "12.34"). Used to pre-fill the controller text for edit
/// flows. NOT used for display formatting elsewhere — `formatInrFromPaise`
/// is the single source of truth for read-side INR rendering.
String _formatPaiseAsEditableText(int paise) {
  final rupees = paise ~/ 100;
  final fractional = paise % 100;
  if (fractional == 0) {
    return _withIndianGrouping(rupees);
  }
  final fractionalStr = fractional.toString().padLeft(2, '0');
  return '${_withIndianGrouping(rupees)}.$fractionalStr';
}

String _withIndianGrouping(int rupees) {
  return NumberFormat.decimalPattern('en_IN').format(rupees);
}

/// Reads the editable text and returns the paise integer it represents.
/// Empty / non-numeric input yields 0.
int _paiseFromText(String raw) {
  if (raw.isEmpty) return 0;

  // Strip the grouping separator (the formatter inserts `,`).
  final cleaned = raw.replaceAll(',', '');
  final dotIndex = cleaned.indexOf('.');

  String rupeesPart;
  String fractionalPart;
  if (dotIndex == -1) {
    rupeesPart = cleaned;
    fractionalPart = '';
  } else {
    rupeesPart = cleaned.substring(0, dotIndex);
    fractionalPart = cleaned.substring(dotIndex + 1);
  }

  final rupees = rupeesPart.isEmpty ? 0 : int.tryParse(rupeesPart) ?? 0;
  final paddedFractional = fractionalPart.padRight(2, '0').substring(0, 2);
  final fractional = int.tryParse(paddedFractional) ?? 0;

  return rupees * 100 + fractional;
}

/// A [TextInputFormatter] that enforces the OBTAmountInput contract.
class _RupeeInputFormatter extends TextInputFormatter {
  _RupeeInputFormatter({required this.maxPaise});

  final int maxPaise;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;

    // Strip everything that is not a digit or a dot — refuses letters,
    // minus signs, currency symbols, whitespace, etc.
    final filtered = raw.replaceAll(RegExp('[^0-9.]'), '');

    // Honour at most one decimal point. Drop every subsequent dot.
    final firstDot = filtered.indexOf('.');
    String singleDot;
    if (firstDot == -1) {
      singleDot = filtered;
    } else {
      final head = filtered.substring(0, firstDot + 1);
      final tail = filtered.substring(firstDot + 1).replaceAll('.', '');
      singleDot = '$head$tail';
    }

    // Clamp to at most two fractional digits.
    String capped;
    final dotIndex = singleDot.indexOf('.');
    if (dotIndex == -1) {
      capped = singleDot;
    } else {
      final rupees = singleDot.substring(0, dotIndex);
      final fractional = singleDot.substring(dotIndex + 1);
      final twoFractional = fractional.length > 2
          ? fractional.substring(0, 2)
          : fractional;
      capped = '$rupees.$twoFractional';
    }

    // Enforce the cap. Strip leading zeros on the rupees component to
    // compute the candidate value, but preserve a single "0" prefix
    // when the user is typing "0.xx".
    final candidatePaise = _paiseFromText(capped);
    if (candidatePaise > maxPaise) {
      // Reject the keystroke: keep the previous text and selection.
      return oldValue;
    }

    // Render the rupee component with Indian-numbering grouping. The
    // fractional part (and any trailing dot the user just typed) is
    // preserved verbatim — we never reformat a partially-typed
    // fractional.
    final dotIdx = capped.indexOf('.');
    String displayed;
    if (dotIdx == -1) {
      final rupeesInt = capped.isEmpty ? 0 : int.tryParse(capped) ?? 0;
      displayed = capped.isEmpty ? '' : _withIndianGrouping(rupeesInt);
    } else {
      final rupeesText = capped.substring(0, dotIdx);
      final tail = capped.substring(dotIdx);
      final rupeesInt = rupeesText.isEmpty ? 0 : int.tryParse(rupeesText) ?? 0;
      final groupedRupees = rupeesText.isEmpty
          ? '0'
          : _withIndianGrouping(rupeesInt);
      displayed = '$groupedRupees$tail';
    }

    return TextEditingValue(
      text: displayed,
      selection: TextSelection.collapsed(offset: displayed.length),
    );
  }
}
