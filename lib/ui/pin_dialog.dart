import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';

/// Asks for a 4-digit PIN until [check] accepts it. False if cancelled.
Future<bool> askPin(BuildContext context,
    {required String title, String? message, required bool Function(String pin) check}) async {
  final pin = await _showPad(context, title: title, message: message,
      validate: (pin) => check(pin) ? null : 'That PIN isn\'t right. Try again.');
  return pin != null;
}

/// Asks for a new PIN, then for it again to confirm. Null if cancelled.
Future<String?> chooseNewPin(BuildContext context, {required String title}) async {
  final first = await _showPad(context, title: title, message: 'Choose 4 digits.');
  if (first == null || !context.mounted) return null;
  return _showPad(context,
      title: title,
      message: 'Enter the same 4 digits again.',
      validate: (pin) => pin == first ? null : 'Those didn\'t match. Try again.');
}

Future<String?> _showPad(BuildContext context,
        {required String title, String? message, String? Function(String pin)? validate}) =>
    showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _PinPad(title: title, message: message, validate: validate),
    );

class _PinPad extends StatefulWidget {
  const _PinPad({required this.title, this.message, this.validate});

  final String title;
  final String? message;

  /// Returns an error to show (and clears the digits), or null to accept.
  final String? Function(String pin)? validate;

  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> {
  String _digits = '';
  String? _error;

  void _type(String digit) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits += digit;
      _error = null;
    });
    if (_digits.length == 4) {
      final error = widget.validate?.call(_digits);
      if (error == null) {
        Navigator.of(context).pop(_digits);
      } else {
        setState(() {
          _error = error;
          _digits = '';
        });
      }
    }
  }

  void _erase() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final label = key.keyLabel;
    if (RegExp(r'^[0-9]$').hasMatch(label)) {
      _type(label);
    } else if (key.keyId >= LogicalKeyboardKey.numpad0.keyId && key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
      _type('${key.keyId - LogicalKeyboardKey.numpad0.keyId}');
    } else if (key == LogicalKeyboardKey.backspace) {
      _erase();
    } else if (isBackKey(key)) {
      Navigator.of(context).pop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    Widget key(String label, {VoidCallback? onPressed, bool autofocus = false, IconData? icon}) => SizedBox(
          width: 150,
          child: TvButton(
            label: label,
            icon: icon,
            expand: true,
            autofocus: autofocus,
            onPressed: onPressed ?? () => _type(label),
          ),
        );

    return Focus(
      onKeyEvent: _onKey,
      child: Dialog(
        backgroundColor: g.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(g.radius * 2),
          side: BorderSide(color: g.cellBorder, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(56),
          child: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title, textAlign: TextAlign.center, style: g.display(44, weight: FontWeight.w800)),
                if (widget.message != null) ...[
                  const SizedBox(height: 10),
                  Text(widget.message!, textAlign: TextAlign.center, style: g.body(26, color: g.textDim)),
                ],
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 72,
                        height: 88,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: g.cell,
                          borderRadius: BorderRadius.circular(g.radius),
                          border: Border.all(color: i == _digits.length ? g.focus : g.cellBorder, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: i < _digits.length
                            ? Icon(Icons.circle, size: 28, color: g.text)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
                SizedBox(
                  height: 56,
                  child: Center(
                    child: Text(_error ?? '', style: g.body(24, weight: FontWeight.w600, color: g.nowLine)),
                  ),
                ),
                FocusTraversalGroup(
                  child: Column(
                    children: [
                      for (final row in const [
                        ['1', '2', '3'],
                        ['4', '5', '6'],
                        ['7', '8', '9'],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [for (final d in row) key(d, autofocus: d == '1')],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          key('Cancel', onPressed: () => Navigator.of(context).pop()),
                          key('0'),
                          key('', icon: Icons.backspace_outlined, onPressed: _erase),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
