import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

/// Six-box auto-advance OTP input (foundation plan section 4.2 #11).
///
/// Promotes the proven `OtpInput` behaviour — six cells, auto-advance on
/// digit entry, backspace navigation, clipboard paste distribution, and
/// the `digits`-reset-clears-cells contract — reskinned to the Haldi
/// tokens: cell corners at [AppTheme.radiusChipInput], the active border
/// in marigold [ColorScheme.primary], the error border in
/// [ColorScheme.error], and Bricolage tabular digits. An optional
/// [errorText] expresses the error state.
class OBTOtpInput extends StatefulWidget {
  /// Creates an [OBTOtpInput].
  const OBTOtpInput({
    required this.onDigitEntered,
    required this.onCompleted,
    required this.onBackspace,
    this.digits,
    this.errorText,
    super.key,
  });

  /// The authoritative digit values from the controller, when tracked.
  /// When supplied and they become all-empty (e.g. the controller resets
  /// after an invalid code), the widget clears its own cells so the user
  /// can retype. When null, the widget is fully self-managed.
  final List<String>? digits;

  /// Called when a digit is entered at the given index.
  final void Function(int index, String digit) onDigitEntered;

  /// Called when all six digits have been filled (paste or typing). The
  /// parameter is the concatenated 6-digit string.
  final void Function(String otp) onCompleted;

  /// Called when backspace is pressed at the given index.
  final void Function(int index) onBackspace;

  /// Optional error message; when set, the cells take the danger border
  /// and the message is shown beneath the row.
  final String? errorText;

  @override
  State<OBTOtpInput> createState() => _OBTOtpInputState();
}

class _OBTOtpInputState extends State<OBTOtpInput> {
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

  @override
  void didUpdateWidget(OBTOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the caller tracks digits and the controller resets every one
    // to empty — e.g. after an invalid code — clear the visual cells and
    // refocus the first so the user can retype. Programmatic controller
    // edits do not fire onChanged, so there is no feedback loop.
    final tracked = widget.digits;
    final controllerCleared =
        tracked != null && tracked.every((d) => d.isEmpty);
    final cellsHaveContent = _controllers.any((c) => c.text.isNotEmpty);
    if (controllerCleared && cellsHaveContent) {
      for (final c in _controllers) {
        c.clear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }
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
        widget.onDigitEntered(index, value);
        if (index < _cellCount - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _focusNodes[index + 1].requestFocus();
            }
          });
        }
        _checkCompleted();
      } else if (value.length > 1) {
        _controllers[index].clear();
      } else if (value.isEmpty) {
        // Digit was deleted via normal means.
      } else {
        _controllers[index].clear();
      }
    } finally {
      _handling = false;
    }
  }

  void _distributePaste(String candidate) {
    if (!RegExp(r'^\d{6}$').hasMatch(candidate)) {
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
    final hasError = widget.errorText != null;
    // Bricolage tabular digits (OBTText.amount is the Bricolage tabular
    // slot), sized up for the OTP cells.
    final digitStyle = OBTText.amount(context).copyWith(fontSize: 22);

    return Semantics(
      label: 'Enter 6-digit verification code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              const maxCell = 48.0;
              const maxGap = 12.0;
              final available = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : maxCell * _cellCount + maxGap * (_cellCount - 1);
              final gap =
                  (maxGap *
                          (available /
                              (maxCell * _cellCount +
                                  maxGap * (_cellCount - 1))))
                      .clamp(4.0, maxGap);
              final totalGap = gap * (_cellCount - 1);
              final cell = ((available - totalGap) / _cellCount).clamp(
                0.0,
                maxCell,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_cellCount, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _cellCount - 1 ? gap : 0,
                    ),
                    child: SizedBox(
                      width: cell,
                      height: maxCell,
                      child: Semantics(
                        label: 'Digit ${index + 1} of $_cellCount',
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: digitStyle,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.zero,
                            counterText: '',
                            enabledBorder: _border(
                              hasError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                            focusedBorder: _border(
                              hasError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) => _onChanged(index, value),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          if (hasError) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              widget.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
