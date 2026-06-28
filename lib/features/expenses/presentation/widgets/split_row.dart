import 'package:flutter/material.dart';

import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/core/widgets/inputs/obt_amount_input.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

/// One per-member row on the Step 2 split table.
///
/// - For [SplitMethod.equal]: read-only [Text] showing the formatted
///   share (Indian-numbering INR via [formatInrFromPaise]).
/// - For [SplitMethod.exact]: editable [OBTAmountInput] that emits
///   paise on every keystroke via [onChanged].
///
/// Future extraction note: a follow-up replaces the layout with a
/// reusable OBTSplitRow.
class SplitRow extends StatelessWidget {
  /// Creates a [SplitRow].
  const SplitRow({
    required this.label,
    required this.method,
    required this.paise,
    required this.onChanged,
    super.key,
  });

  /// Display label for the member ("You" / "Friend").
  final String label;

  /// Current split method — controls whether the value is editable.
  final SplitMethod method;

  /// Share amount in paise.
  final int paise;

  /// Fires on every keystroke when [method] == [SplitMethod.exact].
  /// `null` when the row is read-only.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        Expanded(
          child: method == SplitMethod.exact && onChanged != null
              ? OBTAmountInput(
                  autoFocus: false,
                  initialAmountPaise: paise,
                  onChanged: onChanged!,
                )
              : Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatInrFromPaise(paise),
                      style: OBTText.amount(context),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
