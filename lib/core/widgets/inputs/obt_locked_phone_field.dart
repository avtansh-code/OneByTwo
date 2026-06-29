import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/widgets/india_phone_input_formatter.dart';

/// A locked `+91` Indian mobile-number field.
///
/// Renders the handoff's unified phone field (`Phase3a - Auth`): a single
/// rounded, bordered control whose left segment is the non-editable `+91`
/// country-code chip (on `surfaceVariant`, separated by a 1px divider) and
/// whose right segment is a borderless [TextField].
///
/// A single outer border wraps both halves so their top and bottom edges
/// always align — a Material `OutlineInputBorder` cannot stretch to match an
/// adjacent fixed-height box, so the two-box approach drifts by a few logical
/// pixels with the real (Hanken) font metrics (#150). Focus is conveyed by the
/// marigold cursor plus a marigold outer border.
///
/// The `+91` prefix is locked because v1.0 supports Indian numbers only
/// (SRS section 1.3); the caller supplies any extra [inputFormatters]
/// (`IndianPhoneInputFormatter` is always applied first).
class OBTLockedPhoneField extends StatefulWidget {
  /// Creates a locked `+91` phone-number field.
  const OBTLockedPhoneField({
    super.key,
    this.controller,
    this.onChanged,
    this.enabled = true,
    this.hintText = 'Enter mobile number',
    this.hasError = false,
    this.autofocus = false,
    this.inputFormatters = const [],
  });

  /// Optional controller for the editable portion.
  final TextEditingController? controller;

  /// Called with the raw editable text whenever it changes.
  final ValueChanged<String>? onChanged;

  /// Whether the field accepts input.
  final bool enabled;

  /// Placeholder shown when the field is empty.
  final String hintText;

  /// When true the outer border uses the error colour.
  final bool hasError;

  /// Whether the field requests focus on first build.
  final bool autofocus;

  /// Extra formatters applied after [IndianPhoneInputFormatter].
  final List<TextInputFormatter> inputFormatters;

  @override
  State<OBTLockedPhoneField> createState() => _OBTLockedPhoneFieldState();
}

class _OBTLockedPhoneFieldState extends State<OBTLockedPhoneField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = widget.hasError
        ? colorScheme.error
        : _focusNode.hasFocus
        ? colorScheme.primary
        : colorScheme.outline;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Locked +91 country-code chip with a divider.
              Semantics(
                label: 'Country code, India, plus 91',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    border: Border(
                      right: BorderSide(color: colorScheme.outline),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+91',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              // Editable number, borderless inside the shared frame.
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    IndianPhoneInputFormatter(),
                    ...widget.inputFormatters,
                  ],
                  onChanged: widget.onChanged,
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
