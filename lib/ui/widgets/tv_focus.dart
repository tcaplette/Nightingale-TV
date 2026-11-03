import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tv_theme.dart';
import 'screen_layout.dart';

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

/// Focusable, clickable surface for 10-foot UIs. Moving a mouse or air mouse
/// over it moves focus to it, so pointer and arrow keys share one highlight.
/// Only real pointer movement counts: content scrolling under a still pointer
/// doesn't take focus, and focus taken by the pointer doesn't scroll.
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

  /// Set while the pointer is taking focus, so the focus change doesn't
  /// scroll: the item is under the pointer, so it's already in view.
  bool _pointerFocus = false;

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
      onFocusChange: (f) {
        setState(() => _focused = f);
        widget.onFocusChanged?.call(f);
        if (f && !_pointerFocus) {
          Scrollable.ensureVisible(context,
              alignment: 0.5, duration: const Duration(milliseconds: 150));
        }
        _pointerFocus = false;
      },
      // Hover events come only from a moving pointer; the enter events
      // sent when a list scrolls under a still one would steal focus.
      child: MouseRegion(
        onHover: (_) {
          _pointerFocus = false;
          if (!enabled || _node.hasFocus) return;
          _pointerFocus = true;
          _node.requestFocus();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: widget.builder(context, _focused),
        ),
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
    this.maxLines = 1,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool expand;
  final bool danger;

  /// Lines a long label may wrap to before it's cut short (a phone held
  /// upright).
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final portrait = ScreenLayout.of(context).isPortrait;
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
          child: ConstrainedBox(
            // Upright on a phone: at least 76 units (48 dp) in all.
            constraints: BoxConstraints(minHeight: portrait ? 36 : 0),
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
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: g.display(30, weight: FontWeight.w600, color: fg)),
                ),
              ],
            ),
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
  const TvPage({super.key, required this.title, required this.child, this.hints, this.onBack, this.leading});

  final String title;

  /// Shown before the title, such as the app's mark on its own screens.
  final Widget? leading;
  final Widget child;
  final String? hints;
  final VoidCallback? onBack;

  @override
  State<TvPage> createState() => _TvPageState();
}

/// Whether [node] is a [TvPage]'s own focus: the page holds focus, but no
/// control on it does. (A type check, since `debugLabel` is dropped in
/// release builds.)
bool isTvPageFocus(FocusNode? node) => node is _PageFocusNode;

class _PageFocusNode extends FocusNode {
  _PageFocusNode() : super(debugLabel: 'page', skipTraversal: true);
}

class _TvPageState extends State<TvPage> {
  final _node = _PageFocusNode();

  /// The page's content, kept (with its state) when the layout changes.
  final _body = GlobalKey(debugLabel: 'page body');

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
    if (scope == null || FocusManager.instance.primaryFocus != scope || !_current) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _current && FocusManager.instance.primaryFocus == scope) _node.requestFocus();
    });
  }

  /// A page on its way out (popped, still animating) leaves focus alone:
  /// it belongs to the screen it uncovers.
  bool get _current => ModalRoute.of(context)?.isCurrent ?? true;

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
      child: ScreenLayout.of(context).isPortrait
          ? _portrait(context)
          : DecoratedBox(
        decoration: g.backdrop,
        child: Column(
          children: [
            Container(
              height: 110,
              color: g.header,
              padding: const EdgeInsets.symmetric(horizontal: 80),
              alignment: Alignment.centerLeft,
              child: Row(children: [
                if (widget.leading case final leading?) ...[leading, const SizedBox(width: 24)],
                Flexible(
                  child: Text(widget.title.toUpperCase(), style: g.display(52, weight: FontWeight.w800, color: g.accent)),
                ),
              ]),
            ),
            Expanded(child: KeyedSubtree(key: _body, child: widget.child)),
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

  /// Upright on a phone: clear of the system bars, a back arrow in a
  /// shorter title bar, and no key hints (phones have the back gesture).
  Widget _portrait(BuildContext context) {
    final g = context.guide;
    final layout = ScreenLayout.of(context);
    final safe = MediaQuery.paddingOf(context);
    final onBack = widget.onBack;
    return DecoratedBox(
      decoration: g.backdrop,
      child: Column(
        children: [
          Container(
            color: g.header,
            padding: EdgeInsets.only(top: safe.top, left: safe.left, right: safe.right),
            child: SizedBox(
              height: 96,
              child: Row(
                children: [
                  if (onBack != null)
                    _BackArrow(onPressed: onBack)
                  else
                    SizedBox(width: layout.gutter),
                  if (widget.leading case final leading?) ...[leading, const SizedBox(width: 16)],
                  Expanded(
                    child: Text(widget.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: g.display(40, weight: FontWeight.w800, color: g.accent)),
                  ),
                  SizedBox(width: layout.gutter),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: safe.left, right: safe.right, bottom: safe.bottom),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                removeLeft: true,
                removeRight: true,
                child: KeyedSubtree(key: _body, child: widget.child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The portrait title bar's back arrow: touch-sized, and out of the way of
/// the arrow keys (Back already does the same).
class _BackArrow extends StatelessWidget {
  const _BackArrow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            width: 96,
            height: 96,
            child: Icon(Icons.arrow_back, size: 44, color: g.text),
          ),
        ),
      ),
    );
  }
}

/// The width for a dialog's content: [preferred] in the TV layout; upright,
/// at most what fits between the gutters, less the dialog's own [padding]
/// on each side.
double dialogWidth(BuildContext context, double preferred, {double padding = 0}) {
  final layout = ScreenLayout.of(context);
  if (layout.isTv) return preferred;
  return min(preferred, layout.canvas.width - 2 * layout.gutter - 2 * padding);
}

/// A dialog's content: upright it scrolls, in case the screen is too short
/// for it.
Widget dialogBody(BuildContext context, Widget child) =>
    ScreenLayout.of(context).isPortrait ? SingleChildScrollView(child: child) : child;

/// A dialog's padding: [preferred] in the TV layout, less upright.
double dialogPadding(BuildContext context, [double preferred = 56]) =>
    ScreenLayout.of(context).isPortrait ? min(preferred, 32) : preferred;

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
    this.onHover,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlighted;

  /// Called when the pointer moves onto the button. An owner that passes it
  /// keeps the one highlight itself (pointer and D-pad share it), so the
  /// button then draws only [highlighted].
  final VoidCallback? onHover;

  @override
  State<TvPointerButton> createState() => _TvPointerButtonState();
}

class _TvPointerButtonState extends State<TvPointerButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final on = widget.highlighted || (widget.onHover == null && _hover);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        widget.onHover?.call();
        setState(() => _hover = true);
      },
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
