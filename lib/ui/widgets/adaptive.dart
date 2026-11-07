import 'dart:async';

import 'package:flutter/material.dart';

import 'screen_layout.dart';
import 'tv_focus.dart';

/// A main column with a side panel beside it (portrait-layout): in the TV
/// layout today's row, the main column scrolling at [mainPadding] and the
/// panel [sideWidth] wide on the right; upright, one scrolling column with
/// the panel after the main content (or before it, with [sideFirst]).
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    required this.main,
    required this.side,
    required this.sideWidth,
    this.mainPadding = const EdgeInsets.fromLTRB(80, 40, 40, 40),
    this.sideFirst = false,
    this.controller,
  });

  final List<Widget> main;
  final Widget side;
  final double sideWidth;
  final EdgeInsets mainPadding;
  final bool sideFirst;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final layout = ScreenLayout.of(context);
    if (layout.isPortrait) {
      return FocusTraversalGroup(
        child: ListView(
          controller: controller,
          padding: EdgeInsets.symmetric(horizontal: layout.gutter, vertical: 24),
          children: [
            if (sideFirst) ...[side, const SizedBox(height: 32)],
            ...main,
            if (!sideFirst) ...[const SizedBox(height: 32), side],
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FocusTraversalGroup(
            child: ListView(controller: controller, padding: mainPadding, children: main),
          ),
        ),
        // Gives way to the field being edited, its state kept.
        Offstage(
          offstage: ScreenLayout.keyboardTakesRoom(context),
          child: SizedBox(width: sideWidth, child: side),
        ),
      ],
    );
  }
}

/// A list whose selected item's detail shows beside it in the TV layout,
/// and as its own page upright (portrait-layout): tapping a row there calls
/// [ListDetail.open], which pushes a [TvPage] titled [detailTitle] with
/// [detail]; Back comes back to the list where it was.
///
/// Turning to landscape with a detail page open closes the page, and the
/// side-by-side layout shows that item; turning upright opens the selected
/// item's page.
class ListDetail extends StatefulWidget {
  const ListDetail({
    super.key,
    required this.list,
    required this.detail,
    required this.detailTitle,
    required this.tv,
    this.hasSelection = true,
  });

  /// The list, as the TV layout shows it.
  final Widget list;

  /// The selected item's detail (built again whenever this is).
  final WidgetBuilder detail;
  final String detailTitle;

  /// The TV layout: [list] and the detail side by side.
  final Widget Function(BuildContext context, Widget list, Widget detail) tv;

  /// An item is selected, so its page can open.
  final bool hasSelection;

  /// Upright, opens the selected item's page (in the TV layout the detail
  /// is already showing).
  static void open(BuildContext context) => context.findAncestorStateOfType<_ListDetailState>()?._open();

  @override
  State<ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends State<ListDetail> {
  Route<void>? _page;
  final _listKey = GlobalKey(debugLabel: 'list');
  final _rebuild = ValueNotifier(0);
  bool? _portrait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final portrait = ScreenLayout.of(context).isPortrait;
    if (_portrait != null && portrait != _portrait) {
      if (portrait) {
        // The item selected beside the list opens as its page.
        if (widget.hasSelection) WidgetsBinding.instance.addPostFrameCallback((_) => _open());
      } else {
        // After this frame: routes can't change while it's built.
        WidgetsBinding.instance.addPostFrameCallback((_) => _close());
      }
    }
    _portrait = portrait;
  }

  @override
  void didUpdateWidget(ListDetail old) {
    super.didUpdateWidget(old);
    // The open page shows what's selected now (after this frame: it's
    // another route).
    if (_page != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  void _refresh() {
    if (mounted) _rebuild.value++;
  }

  @override
  void dispose() {
    _rebuild.dispose();
    super.dispose();
  }

  void _open() {
    if (!mounted || _page != null || !widget.hasSelection || !ScreenLayout.of(context).isPortrait) return;
    final page = MaterialPageRoute<void>(
      builder: (context) => ListenableBuilder(
        listenable: _rebuild,
        builder: (context, _) => TvPage(
          title: widget.detailTitle,
          onBack: () => Navigator.of(context).maybePop(),
          child: mounted ? widget.detail(context) : const SizedBox.shrink(),
        ),
      ),
    );
    _page = page;
    unawaited(Navigator.of(context).push(page).whenComplete(() {
      if (_page == page) _page = null;
    }));
    // Opened from a tap that also changed the selection: the page shows it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// Closes the page without a transition (the layout changed under it).
  void _close() {
    final page = _page;
    _page = null;
    if (page != null && page.isActive) page.navigator?.removeRoute(page);
  }

  @override
  Widget build(BuildContext context) {
    // The same list (its scroll position and focus) in both layouts.
    final list = KeyedSubtree(key: _listKey, child: widget.list);
    if (ScreenLayout.of(context).isPortrait) return list;
    return widget.tv(context, list, Builder(builder: widget.detail));
  }
}

/// Buttons in a row at the end, [spacing] apart (a dialog's Cancel and OK);
/// upright they wrap onto more lines when they don't fit.
class ButtonRow extends StatelessWidget {
  const ButtonRow({super.key, required this.children, this.spacing = 20});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (ScreenLayout.of(context).isPortrait) {
      return SizedBox(
        width: double.infinity,
        child: Wrap(alignment: WrapAlignment.end, spacing: spacing, runSpacing: 16, children: children),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final (i, child) in children.indexed) ...[if (i > 0) SizedBox(width: spacing), child],
      ],
    );
  }
}
