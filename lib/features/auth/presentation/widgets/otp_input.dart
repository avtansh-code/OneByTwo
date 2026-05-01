import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A six-cell OTP input widget for verification code entry.
///
/// Renders six [TextField] cells with auto-advance on digit entry,
/// backspace navigation, and clipboard paste support. Paste is handled
/// through the standard text-input pipeline — when Cmd/Ctrl+V inserts
/// multi-character text into a cell, it is distributed across all cells.
class OtpInput extends StatefulWidget {
  /// Creates an [OtpInput] widget.
  const OtpInput({
    required this.onDigitEntered,
    required this.onCompleted,
    required this.onBackspace,
    super.key,
  });

  /// Called when a digit is entered at the given index.
  final void Function(int index, String digit) onDigitEntered;

  /// Called when all six digits have been filled (e.g. via paste or typing).
  /// The parameter contains the concatenated 6-digit string.
  final void Function(String otp) onCompleted;

  /// Called when backspace is pressed at the given index.
  final void Function(int index) onBackspace;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  static const _cellCount = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_cellCount, (_) => TextEditingController());
    _focusNodes = List.generate(_cellCount, (index) {
      final node = FocusNode()
        ..onKeyEvent = (_, event) => _onKeyEvent(index, event);
      return node;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (_handling) return;
    _handling = true;
    try {
      // Multi-character input — treat as paste from clipboard.
      if (value.length >= _cellCount) {
        _distributePaste(value.substring(0, _cellCount));
        return;
      }

      if (value.length == 1 && RegExp(r'^\d$').hasMatch(value)) {
        // Single digit entered normally.
        widget.onDigitEntered(index, value);
        if (index < _cellCount - 1) {
          _focusNodes[index + 1].requestFocus();
        }
        _checkCompleted();
      } else if (value.length > 1) {
        // Multi-character but fewer than 6 — rejected paste. Clear cell.
        _controllers[index].clear();
      } else if (value.isEmpty) {
        // Digit was deleted via normal means.
      } else {
        // Invalid single character — clear it.
        _controllers[index].clear();
      }
    } finally {
      _handling = false;
    }
  }

  void _distributePaste(String candidate) {
    if (!RegExp(r'^\d{6}$').hasMatch(candidate)) {
      // Not exactly 6 digits — reject the paste. Clear the cell that
      // received the pasted text.
      for (final c in _controllers) {
        if (c.text.length > 1) c.clear();
      }
      return;
    }
    for (var i = 0; i < _cellCount; i++) {
      _controllers[i].text = candidate[i];
      widget.onDigitEntered(i, candidate[i]);
    }
    _focusNodes.last.requestFocus();
    widget.onCompleted(candidate);
  }

  void _checkCompleted() {
    if (_controllers.every((c) => c.text.length == 1)) {
      widget.onCompleted(_controllers.map((c) => c.text).join());
    }
  }

  KeyEventResult _onKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Backspace on an empty cell moves focus to the previous cell.
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      widget.onBackspace(index);
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Enter 6-digit verification code',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_cellCount, (index) {
          return Padding(
            padding: EdgeInsets.only(right: index < _cellCount - 1 ? 8 : 0),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Semantics(
                label: 'Digit ${index + 1} of $_cellCount',
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    counterText: '',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onChanged(index, value),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
