import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tv_theme.dart';

/// True for the keys a TV remote or air mouse sends for "back".
bool isBackKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.escape ||
    key == LogicalKeyboardKey.browserBack ||
    key == LogicalKeyboardKey.goBack ||
    key == LogicalKeyboardKey.backspace;

bool isSelectKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.space;

/// True while a text field has keyboard focus.
bool isEditingText() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() !=
    null;

/// Text field where Up/Down move between fields (single-line fields would
/// otherwise swallow them), so forms work with arrow keys alone.
class TvTextField extends StatelessWidget {
  const TvTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmitted,
    this.focusNode,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          FocusScope.of(context).nextFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          FocusScope.of(context).previousFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: keyboardType,
        style: context.guide.body(30),
        decoration: InputDecoration(labelText: label, hintText: hint),
        onSubmitted: onSubmitted,
        // By default OK ("done") also drops focus, which would leave the
        // arrow keys with nothing to move from. Stay in the field instead.
        onEditingComplete: () {},
      ),
    );
  }
}

/// Focusable, clickable surface for 10-foot UIs. Hovering with a mouse or air
/// mouse moves focus to it, so pointer and arrow keys share one highlight.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.builder,
    this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChanged,
  });

  final Widget Function(BuildContext context, bool focused) builder;
  final VoidCallback? onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onPressed?.call();
          return null;
        }),
      },
      onShowHoverHighlight: (hovering) {
        if (hovering && enabled && !_node.hasFocus) _node.requestFocus();
      },
      onFocusChange: (f) {
        setState(() => _focused = f);
        widget.onFocusChanged?.call(f);
        if (f) {
          Scrollable.ensureVisible(context,
              alignment: 0.5, duration: const Duration(milliseconds: 150));
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: widget.builder(context, _focused),
      ),
    );
  }
}

/// Big pill button with the guide's yellow focus highlight.
class TvButton extends StatelessWidget {
  const TvButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.expand = false,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvFocusable(
      onPressed: onPressed,
      autofocus: autofocus,
      focusNode: focusNode,
      builder: (context, focused) {
        final fg = focused ? g.onFocus : (onPressed == null ? g.textDim : g.text);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          decoration: BoxDecoration(
            color: focused ? (danger ? g.nowLine : g.focus) : g.cell,
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: focused ? Colors.white : g.cellBorder, width: 2),
            boxShadow: focused
                ? [BoxShadow(color: g.focus.withValues(alpha: 0.45), blurRadius: 18)]
                : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 32, color: fg),
                const SizedBox(width: 14),
              ],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: g.display(30, weight: FontWeight.w600, color: fg)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A [TvButton] showing a checkbox (or, with [radio], a radio button).
class TvToggle extends StatelessWidget {
  const TvToggle({
    super.key,
    required this.label,
    required this.on,
    required this.onPressed,
    this.radio = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final bool on;
  final bool radio;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TvButton(
        label: label,
        autofocus: autofocus,
        focusNode: focusNode,
        icon: radio
            ? (on ? Icons.radio_button_checked : Icons.radio_button_off)
            : (on ? Icons.check_box : Icons.check_box_outline_blank),
        onPressed: onPressed,
      );
}

/// Screen frame used by the menu-style screens: title bar, body, key hints.
class TvPage extends StatefulWidget {
  const TvPage({super.key, required this.title, required this.child, this.hints, this.onBack});

  final String title;
  final Widget child;
  final String? hints;
  final VoidCallback? onBack;

  @override
  State<TvPage> createState() => _TvPageState();
}

class _TvPageState extends State<TvPage> {
  final _node = FocusNode(debugLabel: 'page', skipTraversal: true);

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_keepFocusInPage);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepFocusInPage);
    _node.dispose();
    super.dispose();
  }

  /// When the focused widget goes away (or a text field is clicked out of),
  /// focus falls back to the screen's top-level scope, above this page, and
  /// Back and the arrow keys would stop working. Catch it here instead.
  void _keepFocusInPage() {
    final scope = _node.enclosingScope;
    if (scope == null || FocusManager.instance.primaryFocus != scope) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && FocusManager.instance.primaryFocus == scope) _node.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final onBack = widget.onBack;
    final hints = widget.hints;
    return Focus(
      focusNode: _node,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && isBackKey(event.logicalKey) && onBack != null) {
          // Backspace must still delete text inside text fields.
          if (event.logicalKey == LogicalKeyboardKey.backspace && isEditingText()) {
            return KeyEventResult.ignored;
          }
          onBack();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DecoratedBox(
        decoration: g.backdrop,
        child: Column(
          children: [
            Container(
              height: 110,
              color: g.header,
              padding: const EdgeInsets.symmetric(horizontal: 80),
              alignment: Alignment.centerLeft,
              child: Text(widget.title.toUpperCase(),
                  style: g.display(52, weight: FontWeight.w800, color: g.accent)),
            ),
            Expanded(child: widget.child),
            if (hints != null)
              Container(
                height: 64,
                color: g.header,
                alignment: Alignment.center,
                child: Text(hints, style: g.body(22, color: g.textDim)),
              ),
          ],
        ),
      ),
    );
  }
}

/// A pill button for the pointer (mouse or air mouse) that never takes
/// keyboard focus, for overlays on screens whose keys do something else
/// (on the TV screen the arrows change channels). Keyboard users can still
/// show it as [highlighted].
class TvPointerButton extends StatefulWidget {
  const TvPointerButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  State<TvPointerButton> createState() => _TvPointerButtonState();
}

class _TvPointerButtonState extends State<TvPointerButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final on = _hover || widget.highlighted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          decoration: BoxDecoration(
            color: on ? g.focus : g.panel.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: on ? Colors.white : g.cellBorder, width: 2),
            boxShadow: on ? [BoxShadow(color: g.focus.withValues(alpha: 0.45), blurRadius: 18)] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 30, color: on ? g.onFocus : g.text),
              const SizedBox(width: 12),
              Text(widget.label, style: g.display(28, weight: FontWeight.w700, color: on ? g.onFocus : g.text)),
            ],
          ),
        ),
      ),
    );
  }
}
