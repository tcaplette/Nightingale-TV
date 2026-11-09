import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../channels/channel_groups.dart';
import '../theme/tv_theme.dart';
import 'menu_screen.dart' show confirm;
import 'widgets/channel_logo.dart';
import 'widgets/adaptive.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// The guide's tabs (channel-groups): their order, which are shown, and the
/// profile's own groups. Everything is a [TvButton], so the D-pad, the air
/// mouse and touch all work.
class ChannelGroupsScreen extends StatefulWidget {
  const ChannelGroupsScreen({super.key});

  @override
  State<ChannelGroupsScreen> createState() => _ChannelGroupsScreenState();
}

class _ChannelGroupsScreenState extends State<ChannelGroupsScreen> {
  /// The tab whose channels the side panel shows.
  String _shown = GuideTabs.all;

  Future<void> _newGroup() async {
    final name = await askName(context, title: tr.newGroup, action: tr.create);
    if (name == null || !mounted) return;
    final group = await AppScope.read(context).createGroup(name);
    if (!mounted) return;
    setState(() => _shown = group.id);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GroupEditorScreen(group: group)));
  }

  void _open(String tabId) {
    final group = AppScope.read(context).settings.groups.where((g) => g.id == tabId).firstOrNull;
    if (group == null) {
      setState(() => _shown = tabId);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GroupEditorScreen(group: group)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final order = app.allTabIds;
    final hidden = app.settings.hiddenTabs;
    final auto = app.autoGroups;
    final groups = {for (final grp in app.settings.groups) grp.id: grp};
    final shownGroup = groups[_shown];
    final members = [
      for (final c in app.channels)
        if (shownGroup != null ? shownGroup.channelIds.contains(c.id) : auto.contains(_shown, c)) c,
    ];

    final portrait = ScreenLayout.of(context).isPortrait;

    Widget tabRow(int i, String id) {
      final name = TvButton(
        label: [
          app.tabName(id),
          if (groups.containsKey(id)) tr.channels4(groups[id]!.channelIds.length),
          if (GuideTabs.isAutomatic(id) || id == GuideTabs.favorites) tr.automatic2,
        ].join('  '),
        icon: groups.containsKey(id) ? Icons.edit : Icons.auto_awesome,
        expand: true,
        onPressed: () => _open(id),
      );
      final up = TvButton(
        label: tr.up,
        icon: Icons.arrow_upward,
        onPressed: i > 1 ? () => app.moveTab(id, -1) : null,
      );
      final down = TvButton(
        label: tr.down,
        icon: Icons.arrow_downward,
        onPressed: i < order.length - 1 ? () => app.moveTab(id, 1) : null,
      );
      final shown = TvToggle(
        label: tr.shown,
        on: !hidden.contains(id),
        onPressed: () => app.setTabHidden(id, !hidden.contains(id)),
      );
      // Upright, Up, Down and Shown go under the name.
      if (portrait) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            name,
            if (id != GuideTabs.all) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 12, children: [up, down, shown]),
            ],
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: name),
          if (id != GuideTabs.all) ...[
            const SizedBox(width: 12),
            up,
            const SizedBox(width: 12),
            down,
            const SizedBox(width: 12),
            SizedBox(width: 190, child: shown),
          ],
        ],
      );
    }

    final memberRows = [
      for (final c in members)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  '${c.number}',
                  style: g.display(28, weight: FontWeight.w800, color: g.accent),
                ),
              ),
              ChannelLogo(icon: c.icon, size: 40, width: 64, fallbackText: c.displayName),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(26)),
              ),
            ],
          ),
        ),
    ];

    return TvPage(
      title: tr.channelGroups,
      hints: tr.moveOkSelectEsc,
      onBack: () => Navigator.of(context).pop(),
      child: AdaptiveColumns(
        mainPadding: const EdgeInsets.fromLTRB(100, 32, 40, 40),
        sideWidth: 560,
        main: [
          Text(
            tr.theTabsAt,
            style: g.body(24, color: g.textDim),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: TvButton(label: tr.newGroup, icon: Icons.add, autofocus: true, onPressed: _newGroup),
          ),
          const SizedBox(height: 24),
          for (final (i, id) in order.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: portrait ? 24 : 10),
              child: tabRow(i, id),
            ),
        ],
        side: Container(
          margin: portrait ? EdgeInsets.zero : const EdgeInsets.fromLTRB(0, 40, 80, 40),
          padding: EdgeInsets.all(portrait ? 28 : 36),
          decoration: BoxDecoration(
            color: g.panel,
            borderRadius: BorderRadius.circular(g.radius * 2),
            border: Border.all(color: g.cellBorder, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.tabName(_shown).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: g.display(30, weight: FontWeight.w800, color: g.accent),
              ),
              const SizedBox(height: 10),
              Text(GuideTabs.rule(_shown) ?? tr.channelsYouPicked, style: g.body(24, color: g.textDim)),
              const SizedBox(height: 16),
              Text(
                tr.channels3(members.length),
                style: g.display(40, weight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              // Upright the panel scrolls with the page.
              if (portrait) ...memberRows else Expanded(child: ListView(children: memberRows)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the profile's groups: rename, delete, and a checkbox per visible
/// channel in number order.
class GroupEditorScreen extends StatefulWidget {
  const GroupEditorScreen({super.key, required this.group});

  final ChannelGroup group;

  @override
  State<GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends State<GroupEditorScreen> {
  late final _name = TextEditingController(text: widget.group.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    await AppScope.read(context).renameGroup(widget.group, _name.text);
    if (mounted) setState(() => _name.text = widget.group.name);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: tr.delete2(widget.group.name),
      message: tr.itsTabLeaves,
      action: tr.delete,
    );
    if (!ok || !mounted) return;
    await AppScope.read(context).deleteGroup(widget.group);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final group = widget.group;
    final layout = ScreenLayout.of(context);
    final rename = TvButton(label: tr.rename, icon: Icons.check, onPressed: _rename);
    final delete = TvButton(label: tr.deleteGroup, icon: Icons.delete, danger: true, onPressed: _delete);
    return TvPage(
      title: tr.group(group.name),
      hints: tr.moveOkSelectEsc,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: layout.pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            if (layout.isPortrait) ...[
              // Upright, the buttons go under the name.
              TvTextField(controller: _name, label: tr.groupName, onSubmitted: (_) => _rename()),
              const SizedBox(height: 16),
              Wrap(spacing: 16, runSpacing: 16, children: [rename, delete]),
            ] else
            Row(
              children: [
                Expanded(
                  child: TvTextField(controller: _name, label: tr.groupName, onSubmitted: (_) => _rename()),
                ),
                const SizedBox(width: 16),
                rename,
                const SizedBox(width: 16),
                delete,
              ],
            ),
            const SizedBox(height: 32),
            Text(
              tr.channels2,
              style: g.display(26, weight: FontWeight.w800, color: g.accent),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final (i, c) in app.channels.indexed)
                  SizedBox(
                    width: layout.isPortrait ? double.infinity : 820,
                    child: TvToggle(
                      label: '${c.number}   ${c.displayName}',
                      on: group.channelIds.contains(c.id),
                      autofocus: i == 0,
                      onPressed: () => app.setInGroup(group, c, !group.channelIds.contains(c.id)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A TV-friendly name prompt: the text field (with the on-screen keyboard
/// on touch and Android TV) and OK/Cancel. Null when cancelled.
Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
  String? action,
}) async {
  // Not disposed here: the field still shows while the dialog animates out.
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) {
      final g = context.guide;
      void submit() {
        final name = controller.text.trim();
        if (name.isNotEmpty) Navigator.pop(context, name);
      }

      return Dialog(
        backgroundColor: g.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(g.radius * 2),
          side: BorderSide(color: g.cellBorder, width: 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(dialogPadding(context)),
          child: SizedBox(
            width: dialogWidth(context, 820, padding: dialogPadding(context)),
            child: dialogBody(context, Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: g.display(48, weight: FontWeight.w800)),
                const SizedBox(height: 24),
                TvTextField(controller: controller, label: tr.name, autofocus: true, onSubmitted: (_) => submit()),
                const SizedBox(height: 40),
                ButtonRow(
                  children: [
                    TvButton(label: tr.cancel, onPressed: () => Navigator.pop(context)),
                    TvButton(label: action ?? tr.ok, onPressed: submit),
                  ],
                ),
              ],
            )),
          ),
        ),
      );
    },
  );
}
