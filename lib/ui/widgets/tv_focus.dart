import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../platform/platform_info.dart';
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

/// True while typing goes to a text field: one that has keyboard focus and
/// isn't just highlighted (on a TV, [TvTextField] until it's opened).
bool isEditingText() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>()?.readOnly == false;

/// Text field where Up/Down move between fields (single-line fields would
/// otherwise swallow them), so forms work with arrow keys alone.
///
/// On Android the on-screen keyboard can always be left (text-entry). On a
/// TV, focus only highlights the field, so the D-pad can pass through: OK or
/// a click opens the keyboard. An [autofocus] field opens it straight away:
/// typing is what the user came for.
class TvTextField extends StatefulWidget {
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
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> with WidgetsBindingObserver {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  /// On a TV: the keyboard is open, or has been asked for. A read-only field
  /// has no input connection, so no keyboard and D-pad presses reach us.
  late bool _editing = widget.autofocus;

  /// The window's keyboard inset when last looked at. (Below [TvCanvas] the
  /// media query's is always zero.)
  double _inset = 0;

  static bool get _tv => PlatformInfo.isTelevision;

  @override
  void initState() {
    super.initState();
    _node.addListener(_focusChanged);
    if (_tv) {
      WidgetsBinding.instance.addObserver(this);
      PlatformInfo.dpadArrows.addListener(_endEditing);
    }
  }

  @override
  void didUpdateWidget(TvTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_focusChanged);
      _node.addListener(_focusChanged);
    }
  }

  @override
  void dispose() {
    if (_tv) {
      WidgetsBinding.instance.removeObserver(this);
      PlatformInfo.dpadArrows.removeListener(_endEditing);
    }
    _node.removeListener(_focusChanged);
    _ownNode?.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!_tv) return;
    if (!_node.hasFocus) {
      _endEditing();
    } else if (!_editing) {
      // A field being typed in scrolls itself into view; a read-only one
      // doesn't.
      Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
    }
  }

  /// Back closes the keyboard without telling the field: it's seen here, as
  /// the keyboard's inset falling to zero.
  @override
  void didChangeMetrics() {
    final inset = View.maybeOf(context)?.viewInsets.bottom ?? 0;
    final closed = _inset > 0 && inset == 0;
    _inset = inset;
    if (closed) _endEditing();
  }

  void _startEditing() {
    if (!_node.hasFocus) _node.requestFocus();
    setState(() => _editing = true);
  }

  /// Closes the keyboard, and the field stays focused for the arrow keys.
  void _endEditing() {
    if (!_editing || !mounted) return;
    widget.controller.clearComposing();
    setState(() => _editing = false);
  }

  /// Asks for the keyboard again. Some keyboards report no inset, so what
  /// [_editing] says can't be taken as the keyboard being up.
  void _requestKeyboard() =>
      _node.context?.findAncestorStateOfType<EditableTextState>()?.requestKeyboard();

  /// Typing is done: on a TV the field stays focused and the arrow keys work
  /// again; on touch it gives up focus, as is normal there.
  void _closeKeyboard() {
    if (_tv) {
      _endEditing();
    } else {
      _node.unfocus();
    }
  }

  void _submitted(String text) {
    widget.onSubmitted?.call(text);
    if (mounted) _closeKeyboard();
  }

  /// Only OK itself can be taken: Enter while typing also has to reach the
  /// keyboard, as its ✓, and Space has to type.
  KeyEventResult _onSelect(KeyEvent event) {
    final key = event.logicalKey;
    final highlighted = _tv && !_editing;
    if (highlighted) {
      if (event is KeyDownEvent) _startEditing();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) return KeyEventResult.ignored;
    if (event is KeyDownEvent) _requestKeyboard();
    return key == LogicalKeyboardKey.select ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      FocusScope.of(context).nextFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      // What's above it, such as the back button; else the control before it.
      if (!_node.focusInDirection(TraversalDirection.up)) FocusScope.of(context).previousFocus();
      return KeyEventResult.handled;
    }
    if (!PlatformInfo.isAndroid) return KeyEventResult.ignored;
    if (isSelectKey(key)) return _onSelect(event);
    // With nothing being typed there's no caret for Left and Right to move.
    if (_tv && !_editing) {
      final direction = key == LogicalKeyboardKey.arrowLeft
          ? TraversalDirection.left
          : key == LogicalKeyboardKey.arrowRight
              ? TraversalDirection.right
              : null;
      if (direction != null) {
        _node.focusInDirection(direction);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final android = PlatformInfo.isAndroid;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TextField(
        controller: widget.controller,
        focusNode: _node,
        autofocus: widget.autofocus,
        obscureText: widget.obscure,
        readOnly: _tv && !_editing,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: widget.keyboardType,
        style: context.guide.body(30),
        decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
        onTap: _tv ? _startEditing : null,
        onTapAlwaysCalled: _tv,
        // On the pointer's release, not its press: the layout mustn't jump
        // under a finger still pressing a button.
        onTapOutside: android ? (_) {} : null,
        onTapUpOutside: android
            ? (_) {
                if (_node.hasFocus) _closeKeyboard();
              }
            : null,
        onSubmitted: android ? _submitted : widget.onSubmitted,
        // By default OK ("done") also drops focus, which on the PC would
        // leave the arrow keys with nothing to move from. Stay in the field
        // instead; on Android, _submitted closes the keyboard.
        onEditingComplete: android ? widget.controller.clearComposing : () {},
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
  final _backNode = FocusNode(debugLabel: 'back button');

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
    _backNode.dispose();
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

  /// Only the page holds focus, so there's no control for an arrow key to
  /// move from: it goes to the first one in the content, and to the back
  /// button only if the content has none.
  KeyEventResult _arrowFromPage() {
    final scope = _node.enclosingScope;
    if (scope == null) return KeyEventResult.ignored;
    final controls = [
      for (final node in scope.traversalDescendants)
        if (node != _backNode && node is! FocusScopeNode) node,
    ];
    if (controls.isEmpty) {
      if (widget.onBack == null) return KeyEventResult.ignored;
      _backNode.requestFocus();
      return KeyEventResult.handled;
    }
    int byPosition(FocusNode a, FocusNode b) {
      final top = a.rect.top.compareTo(b.rect.top);
      return top != 0 ? top : a.rect.left.compareTo(b.rect.left);
    }
    controls.reduce((a, b) => byPosition(b, a) < 0 ? b : a).requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final onBack = widget.onBack;
    final hints = widget.hints;
    return Focus(
      focusNode: _node,
      onKeyEvent: (node, event) {
        if (event is! KeyUpEvent && _isArrow(event.logicalKey) && _node.hasPrimaryFocus) {
          return _arrowFromPage();
        }
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
              // The button takes the margin's place, clear of a camera cutout.
              padding: EdgeInsets.only(left: onBack != null ? MediaQuery.paddingOf(context).left : 80, right: 80),
              alignment: Alignment.centerLeft,
              child: Row(children: [
                if (onBack != null) ...[
                  _BackButton(focusNode: _backNode, onPressed: onBack, height: 110, labelled: true),
                  const SizedBox(width: 12),
                ],
                if (widget.leading case final leading?) ...[leading, const SizedBox(width: 24)],
                Flexible(
                  child: Text(widget.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: g.display(52, weight: FontWeight.w800, color: g.accent)),
                ),
              ]),
            ),
            Expanded(child: KeyedSubtree(key: _body, child: widget.child)),
            if (hints != null && !ScreenLayout.keyboardTakesRoom(context))
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
                    _BackButton(focusNode: _backNode, onPressed: onBack, height: 96, labelled: false)
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

bool _isArrow(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.arrowUp ||
    key == LogicalKeyboardKey.arrowDown ||
    key == LogicalKeyboardKey.arrowLeft ||
    key == LogicalKeyboardKey.arrowRight;

/// The title bar's back button, on every platform and for every input. All
/// of it can be pressed, the bar's full [height] and at least 140 units wide
/// in the TV layout: a phone held sideways draws the canvas at about 0.38, so
/// a pill-sized target would be too small for a finger.
///
/// With [labelled], the arrow and "Back" in a pill, reading from across a
/// room; without it, the arrow alone, for a narrow title bar.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.focusNode, required this.onPressed, required this.height, required this.labelled});

  final FocusNode focusNode;
  final VoidCallback onPressed;
  final double height;
  final bool labelled;

  /// Where the pill starts when there's room: the content's left margin.
  static const _margin = 80.0;
  static const _minEdge = 16.0;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    // The bar is already inset by a camera cutout's width.
    final inset = MediaQuery.paddingOf(context).left;
    final left = max(_margin - inset, _minEdge);
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      onTap: onPressed,
      child: TvFocusable(
        focusNode: focusNode,
        onPressed: onPressed,
        builder: (context, focused) {
          final fg = focused ? g.onFocus : g.text;
          final decoration = BoxDecoration(
            color: focused ? g.focus : (labelled ? g.cell : null),
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: labelled || focused
                ? Border.all(color: focused ? Colors.white : g.cellBorder, width: 2)
                : null,
            boxShadow: focused ? [BoxShadow(color: g.focus.withValues(alpha: 0.45), blurRadius: 18)] : null,
          );
          if (!labelled) {
            return SizedBox(
              width: height,
              height: height,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: decoration,
                  child: Icon(Icons.arrow_back, size: 44, color: fg),
                ),
              ),
            );
          }
          return ConstrainedBox(
            constraints: BoxConstraints(minWidth: 140, minHeight: height),
            child: Padding(
              padding: EdgeInsets.only(left: left, right: 16),
              child: Center(
                widthFactor: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  decoration: decoration,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 34, color: fg),
                      const SizedBox(width: 12),
                      Text('Back', style: g.display(30, weight: FontWeight.w600, color: fg)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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

/// A dialog's content: on a phone or tablet it scrolls, in case the screen
/// is too short for it, as it is above a keyboard held sideways.
Widget dialogBody(BuildContext context, Widget child) =>
    PlatformInfo.hasTouch ? SingleChildScrollView(child: child) : child;

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
