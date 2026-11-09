import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../channels/channel.dart';
import '../channels/premieres.dart';
import '../channels/program_block.dart';
import '../channels/schedule.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'menu_screen.dart';
import 'source_picker_screen.dart';
import 'widgets/channel_logo.dart';
import 'widgets/new_tag.dart';
import 'widgets/adaptive.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

String _clock(int minute) => formatClockMinute(minute);

/// "8:00 PM · Every day · On"
String describePremieres(PremiereSettings p) =>
    [_clock(p.startMinute), describeDays(p.days), p.enabled ? tr.onLabel2 : tr.off].join('  ·  ');

/// When [b] next starts (or the airing in progress), within about a year.
DateTime? nextAiring(ProgramBlock b, DateTime now) {
  for (var i = -1; i < 400; i++) {
    final d = DateTime(now.year, now.month, now.day + i);
    if (d.isBefore(b.anchor)) continue;
    final w = b.windowOn(d);
    if (w != null && w.end.isAfter(now)) return w.start;
  }
  return null;
}

/// Lists programming blocks: titled lineups like "Saturday Morning Cartoons"
/// that take over a channel on chosen days and times.
class BlocksScreen extends StatelessWidget {
  const BlocksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final now = DateTime.now();

    Future<void> edit(ProgramBlock? block, {bool lateNight = false}) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => BlockEditorScreen(block: block, lateNight: lateNight)),
        );

    final portrait = ScreenLayout.of(context).isPortrait;
    final premiereCaption = Text(tr.newlyAddedEpisodes,
        style: g.body(24, weight: FontWeight.w600, color: g.accent));
    return TvPage(
      title: tr.programmingBlocks,
      hints: tr.moveOkEdit,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(120, 40, 120, 40)),
          children: [
            Text(
              tr.blocksTakeOver,
              style: g.body(28, color: g.textDim),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TvButton(
                  label: tr.newProgrammingBlock,
                  icon: Icons.add,
                  autofocus: app.blocks.isEmpty,
                  onPressed: () => edit(null),
                ),
                // Kid profiles get no late-night shortcut (late-night-drift D6).
                if (app.maxRatingRank == null)
                  TvButton(
                    label: tr.newLateNight,
                    icon: Icons.nightlight_round,
                    onPressed: () => edit(null, lateNight: true),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            // Fixed first: the automatic premiere slot.
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TvFocusable(
                autofocus: app.blocks.isNotEmpty,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const PremiereEditorScreen())),
                builder: (context, focused) => AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  decoration: BoxDecoration(
                    color: focused ? g.cellBorder : g.cell,
                    borderRadius: BorderRadius.circular(g.radius),
                    border: Border.all(color: focused ? g.focus : Colors.transparent, width: 4),
                  ),
                  child: Row(
                    children: [
                      const NewTag(size: 26),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(PremiereEditorScreen.title,
                                style: g.display(38,
                                    weight: FontWeight.w800, color: app.settings.premieres.enabled ? g.text : g.textDim)),
                            Text(describePremieres(app.settings.premieres),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(24, color: g.textDim)),
                            // Upright, under the rest: there's no room beside it.
                            if (portrait) premiereCaption,
                          ],
                        ),
                      ),
                      if (!portrait) ...[const SizedBox(width: 24), premiereCaption],
                    ],
                  ),
                ),
              ),
            ),
            for (final b in app.blocks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BlockRow(
                  block: b,
                  channel: app.channelById(b.channelId),
                  next: nextAiring(b, now),
                  autofocus: false,
                  onPressed: () => edit(b),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.channel,
    required this.next,
    required this.autofocus,
    required this.onPressed,
  });

  final ProgramBlock block;
  final Channel? channel;
  final DateTime? next;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final ch = channel;
    final portrait = ScreenLayout.of(context).isPortrait;
    final status = !block.enabled
        ? tr.turnedOff
        : ch == null
            ? tr.itsChannelIs
            : next == null
                ? tr.noUpcomingAirings
                : next!.isBefore(DateTime.now())
                    ? tr.onTheAirNow2
                    : tr.next(formatDate(next!), formatTime(next!));
    final statusText = Text(status,
        style: g.body(24, weight: FontWeight.w600, color: ch == null && block.enabled ? g.nowLine : g.accent));
    return TvFocusable(
      autofocus: autofocus,
      onPressed: onPressed,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        decoration: BoxDecoration(
          color: focused ? g.cellBorder : g.cell,
          borderRadius: BorderRadius.circular(g.radius),
          border: Border.all(color: focused ? g.focus : Colors.transparent, width: 4),
        ),
        child: Row(
          children: [
            if (ch != null) ...[
              SizedBox(
                width: 80,
                child: Text('${ch.number}', style: g.display(40, weight: FontWeight.w800, color: g.accent)),
              ),
              ChannelLogo(icon: ch.icon, size: 60, width: 100, fallbackText: ch.displayName),
              const SizedBox(width: 24),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: g.display(38,
                          weight: FontWeight.w800, color: block.enabled ? g.text : g.textDim)),
                  Text(
                    [
                      if (block.generated != null) fromTheLineupLabel,
                      describeBlock(block),
                      if (ch != null && ch.displayName != block.title) ch.displayName,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.body(24, color: g.textDim),
                  ),
                  if (portrait) statusText,
                ],
              ),
            ),
            if (!portrait) ...[const SizedBox(width: 24), statusText],
          ],
        ),
      ),
    );
  }
}

/// Create or edit one programming block.
class BlockEditorScreen extends StatefulWidget {
  const BlockEditorScreen({super.key, this.block, this.lateNight = false});

  /// The block to edit; null to create a new one.
  final ProgramBlock? block;

  /// A new block filled in by the late-night shortcut (late-night-drift D4).
  final bool lateNight;

  @override
  State<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends State<BlockEditorScreen> {
  static const _step = 15;

  late final ProgramBlock _draft;
  late final TextEditingController _title;

  /// The block gets a new channel of its own when saved.
  bool _newChannel = false;

  /// Plays a lineup rather than a mix (even while the lineup is empty).
  late bool _lineupMode = _draft.hasLineup;

  /// The lineup while the mix is chosen, so switching back restores it.
  List<LineupSlot> _setAside = [];

  /// Focus for each lineup row's buttons, by position, so the remote's
  /// focus can follow a slot as it moves, or land nearby when the button it
  /// was on turns off or goes away.
  final _rowFocus = <({FocusNode fewer, FocusNode more, FocusNode up, FocusNode down, FocusNode remove})>[];
  final _addFocus = FocusNode();
  String? _error;

  /// The late-night shortcut's source and order follow the chosen channel
  /// until the user changes either.
  late bool _followChannel = _isNew && widget.lateNight;

  bool get _isNew => widget.block == null;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    _draft = widget.block?.copy() ?? app.newBlock();
    if (_followChannel) {
      lateNightDefaults(_draft);
      _copyChannel(app.channelById(_draft.channelId));
    }
    // The summary panel shows the title as it's typed.
    _title = TextEditingController(text: _draft.title)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    for (final row in _rowFocus) {
      _disposeRow(row);
    }
    _addFocus.dispose();
    super.dispose();
  }

  static void _disposeRow(({FocusNode fewer, FocusNode more, FocusNode up, FocusNode down, FocusNode remove}) row) {
    for (final node in [row.fewer, row.more, row.up, row.down, row.remove]) {
      node.dispose();
    }
  }

  void _update(void Function() change) => setState(() {
        change();
        _error = null;
      });

  /// The late-night shortcut: [channel]'s source and order, keeping the
  /// chosen minimum rating.
  void _copyChannel(Channel? channel) {
    if (channel == null) return;
    final floor = _draft.source.ratingFloor;
    _draft.source = lateNightSource(channel).copyWith(ratingFloor: () => floor);
    _draft.order = lateNightOrder(channel, PlaybackOrder.cyclic);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final channel = app.channelById(_draft.channelId);
    // An empty lineup plays nothing (rather than the mix).
    final hasContent = !_lineupMode || _draft.hasLineup;
    final playlist = hasContent ? app.blockPlaylist(_draft) : const <String>[];
    final preview = hasContent ? app.previewBlock(_draft, _newChannel ? null : _draft.channelId) : null;

    return TvPage(
      title: !_isNew ? tr.editProgrammingBlock : widget.lateNight ? tr.newLateNight : tr.newProgrammingBlock,
      hints: tr.moveOkSelectEscCancel,
      onBack: () => Navigator.of(context).pop(),
      // Upright, what the block will air comes first.
      child: AdaptiveColumns(
                mainPadding: const EdgeInsets.fromLTRB(100, 32, 40, 40),
                sideWidth: 640,
                sideFirst: true,
                side: _summary(context, app, channel, playlist, preview),
                main: [
                  TvTextField(
                    controller: _title,
                    label: tr.title,
                    hint: tr.saturdayMorningCartoons,
                    autofocus: _isNew,
                    onSubmitted: (_) => setState(() {}),
                  ),
                  _section(g, tr.channel),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvButton(
                      label: _newChannel
                          ? tr.aNewChannelJust
                          : channel == null
                              ? tr.chooseAChannel2
                              : '${channel.number}  ${channel.displayName}',
                      icon: Icons.tv,
                      autofocus: !_isNew,
                      onPressed: _pickChannel,
                    ),
                  ),
                  _section(g, tr.days),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        TvToggle(
                          label: weekdayName(d),
                          on: _draft.days.contains(d),
                          onPressed: () => _update(() {
                            _draft.days = {..._draft.days};
                            if (!_draft.days.remove(d)) _draft.days.add(d);
                          }),
                        ),
                      const SizedBox(width: 12),
                      TvButton(label: tr.weekdays, onPressed: () => _update(() => _draft.days = {1, 2, 3, 4, 5})),
                      TvButton(label: tr.weekends, onPressed: () => _update(() => _draft.days = {6, 7})),
                      TvButton(
                          label: tr.everyDay, onPressed: () => _update(() => _draft.days = {1, 2, 3, 4, 5, 6, 7})),
                    ],
                  ),
                  _section(g, tr.time),
                  Wrap(
                    spacing: 48,
                    runSpacing: 16,
                    children: [
                      _Stepper(
                        label: tr.starts,
                        value: _clock(_draft.startMinute),
                        onMinus: () => _update(() => _draft.startMinute = _wrap(_draft.startMinute - _step)),
                        onPlus: () => _update(() => _draft.startMinute = _wrap(_draft.startMinute + _step)),
                      ),
                      _Stepper(
                        label: tr.ends,
                        value: _clock(_draft.endMinute) +
                            (_draft.endMinute <= _draft.startMinute ? tr.nextDay : ''),
                        onMinus: () => _update(() => _draft.endMinute = _wrap(_draft.endMinute - _step)),
                        onPlus: () => _update(() => _draft.endMinute = _wrap(_draft.endMinute + _step)),
                      ),
                    ],
                  ),
                  _section(g, tr.dates),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      TvToggle(
                        label: tr.allYear,
                        on: !_draft.hasSeason,
                        radio: true,
                        onPressed: () => _update(() {
                          _draft.seasonStart = null;
                          _draft.seasonEnd = null;
                        }),
                      ),
                      TvToggle(
                        label: tr.onlyBetweenDates,
                        on: _draft.hasSeason,
                        radio: true,
                        onPressed: () => _update(() {
                          _draft.seasonStart ??= const MonthDay(12, 1);
                          _draft.seasonEnd ??= const MonthDay(12, 25);
                        }),
                      ),
                    ],
                  ),
                  if (_draft.hasSeason) ...[
                    const SizedBox(height: 16),
                    _DateStepper(
                      label: tr.from,
                      value: _draft.seasonStart!,
                      onChanged: (v) => _update(() => _draft.seasonStart = v),
                    ),
                    const SizedBox(height: 12),
                    _DateStepper(
                      label: tr.to,
                      value: _draft.seasonEnd!,
                      onChanged: (v) => _update(() => _draft.seasonEnd = v),
                    ),
                    const SizedBox(height: 8),
                    Text(tr.repeatsEveryYear, style: g.body(22, color: g.textDim)),
                  ],
                  _section(g, tr.whatItPlays),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      TvToggle(label: tr.aMix, on: !_lineupMode, radio: true, onPressed: () => _setLineupMode(false)),
                      TvToggle(label: tr.aLineup, on: _lineupMode, radio: true, onPressed: () => _setLineupMode(true)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _lineupMode
                        ? tr.yourShowsIn
                        : tr.showsAndMovies,
                    style: g.body(22, color: g.textDim),
                  ),
                  const SizedBox(height: 16),
                  if (_lineupMode)
                    ..._lineupEditor(app)
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        TvButton(
                          label: tr.chooseShowsMovies,
                          icon: Icons.video_library,
                          onPressed: _pickContent,
                        ),
                        for (final order in PlaybackOrder.values)
                          TvToggle(
                            label: order.label,
                            on: _draft.order == order,
                            radio: true,
                            onPressed: () => _update(() {
                              _draft.order = order;
                              _followChannel = false;
                            }),
                          ),
                      ],
                    ),
                  if (!_lineupMode && app.maxRatingRank == null) ...[
                    const SizedBox(height: 20),
                    Text(tr.minimumRating, style: g.body(24, weight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final floor in <RatingFloor?>[null, ...RatingFloor.values])
                          TvToggle(
                            label: floor?.label ?? tr.anyRating,
                            on: _draft.source.ratingFloor == floor,
                            radio: true,
                            onPressed: () =>
                                _update(() => _draft.source = _draft.source.copyWith(ratingFloor: () => floor)),
                          ),
                      ],
                    ),
                    if (_draft.source.ratingFloor != null) ...[
                      const SizedBox(height: 10),
                      Text(tr.onlyShowsAnd,
                          style: g.body(22, color: g.textDim)),
                    ],
                  ],
                  _section(g, tr.onTheAir),
                  TvToggle(
                    label: _draft.enabled ? tr.blockIsOn : tr.blockIsOff,
                    on: _draft.enabled,
                    onPressed: () => _update(() => _draft.enabled = !_draft.enabled),
                  ),
                  const SizedBox(height: 40),
                  if (_error != null) ...[
                    Text(_error!, style: g.body(28, weight: FontWeight.w600, color: g.nowLine)),
                    const SizedBox(height: 20),
                  ],
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      TvButton(label: tr.save, icon: Icons.check, onPressed: _save),
                      TvButton(label: tr.cancel, onPressed: () => Navigator.of(context).pop()),
                      if (!_isNew)
                        TvButton(label: tr.deleteBlock, icon: Icons.delete, danger: true, onPressed: _delete),
                    ],
                  ),
                ],
      ),
    );
  }

  Widget _summary(BuildContext context, AppState app, Channel? channel, List<String> playlist,
      ({Airing airing, List<ScheduledProgram> programs})? preview) {
    final g = context.guide;
    final shows = <String>{};
    var movies = 0;
    var runtime = Duration.zero;
    for (final id in playlist) {
      final item = app.library[id];
      if (item == null) continue;
      runtime += item.runtime;
      if (item.seriesName != null) {
        shows.add(item.seriesName!);
      } else {
        movies++;
      }
    }
    final title = _title.text.trim();
    final portrait = ScreenLayout.of(context).isPortrait;
    return Container(
      margin: portrait ? EdgeInsets.zero : const EdgeInsets.fromLTRB(0, 32, 80, 40),
      padding: EdgeInsets.all(portrait ? 28 : 36),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(g.radius * 2),
        border: Border.all(color: g.cellBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            color: g.accent,
            child: Text(
              (title.isEmpty ? tr.untitledBlock : title).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: g.display(26, weight: FontWeight.w800, color: g.onFocus),
            ),
          ),
          const SizedBox(height: 20),
          Text(describeBlock(_draft), style: g.display(30, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_draft.generated != null) ...[
            Text('$fromTheLineupLabel. $fromTheLineupNote', style: g.body(24, color: g.accent)),
            const SizedBox(height: 8),
          ],
          Text(
            _newChannel
                ? tr.onANew
                : channel == null
                    ? tr.noChannelChosen
                    : tr.onLabel(channel.number, channel.displayName),
            style: g.body(24, color: g.textDim),
          ),
          const SizedBox(height: 32),
          Text(tr.plays, style: g.display(24, weight: FontWeight.w800, color: g.accent)),
          const SizedBox(height: 8),
          if (playlist.isEmpty)
            Text(_lineupMode ? tr.nothingYetAdd : tr.nothingYetChoose,
                style: g.body(26, color: g.textDim))
          else ...[
            Text(
              _lineupMode
                  ? [
                      tr.countSlots(_draft.lineup.length),
                      tr.shows(shows.length),
                    ].join(' · ')
                  : [
                      if (shows.isNotEmpty) tr.shows(shows.length),
                      if (movies > 0) tr.movies2(movies),
                      tr.inAll(formatMinutes(runtime)),
                    ].join(' · '),
              style: g.body(26),
            ),
            const SizedBox(height: 4),
            if (_lineupMode && preview != null)
              Text(_lineupFit(preview), style: g.body(22, color: g.textDim))
            else if (!_lineupMode)
              Text(
                shows.take(6).join(', ') + (shows.length > 6 ? '…' : ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: g.body(22, color: g.textDim),
              ),
          ],
          if (preview != null) ...[
            const SizedBox(height: 28),
            Text(
              preview.airing.start.isAfter(DateTime.now())
                  ? tr.nextAiring(formatDate(preview.airing.start))
                  : tr.onTheAirNow,
              style: g.display(24, weight: FontWeight.w800, color: g.accent),
            ),
            const SizedBox(height: 8),
            // Upright the panel scrolls with the page.
            if (portrait)
              for (final p in preview.programs) _PreviewRow(program: p)
            else
              Expanded(
                child: ListView(
                  primary: false,
                  children: [for (final p in preview.programs) _PreviewRow(program: p)],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// How the lineup fills the block: "Runs 1 hr 6 min, then starts over."
  String _lineupFit(({Airing airing, List<ScheduledProgram> programs}) preview) {
    final perPass = _draft.lineup.fold(0, (n, s) => n + s.count);
    final programs = preview.programs;
    final last = programs.last;
    final cutOff = last.end == preview.airing.end && last.duration < (last.item?.runtime ?? Duration.zero);
    if (programs.length < perPass || (programs.length == perPass && cutOff)) {
      return tr.longerThanThe(formatTime(preview.airing.end), last.title);
    }
    if (programs.length == perPass) return tr.fillsTheBlock;
    return tr.runsThenStarts(formatMinutes(programs[perPass - 1].end.difference(preview.airing.start)));
  }

  /// The lineup's slots, each with its episode count and moves, then
  /// "Add a show".
  List<Widget> _lineupEditor(AppState app) {
    final slots = _draft.lineup;
    while (_rowFocus.length < slots.length) {
      _rowFocus.add((fewer: FocusNode(), more: FocusNode(), up: FocusNode(), down: FocusNode(), remove: FocusNode()));
    }
    while (_rowFocus.length > slots.length) {
      // Disposed after the frame, once the row's buttons let go of them.
      final row = _rowFocus.removeLast();
      WidgetsBinding.instance.addPostFrameCallback((_) => _disposeRow(row));
    }
    // Changes the lineup, then focuses [focus] (worked out once the rows
    // are rebuilt).
    void edit(void Function(List<LineupSlot> slots) change, FocusNode Function() focus) {
      _update(() {
        final copy = [for (final s in slots) LineupSlot(seriesKey: s.seriesKey, count: s.count)];
        change(copy);
        _draft.lineup = copy;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus().requestFocus();
      });
    }

    final last = slots.length - 1;
    return [
      for (final (i, slot) in slots.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LineupRow(
            number: i + 1,
            name: app.library.seriesByKey[slot.seriesKey]?.name ?? tr.missingShow,
            count: slot.count,
            focus: _rowFocus[i],
            // At a limit a button turns off; focus moves to its partner.
            onFewer: slot.count > 1
                ? () => edit((s) => s[i].count--, () => slot.count - 1 > 1 ? _rowFocus[i].fewer : _rowFocus[i].more)
                : null,
            onMore: slot.count < LineupSlot.maxCount
                ? () => edit((s) => s[i].count++,
                    () => slot.count + 1 < LineupSlot.maxCount ? _rowFocus[i].more : _rowFocus[i].fewer)
                : null,
            onUp: i > 0
                ? () => edit((s) => s.insert(i - 1, s.removeAt(i)),
                    () => i - 1 > 0 ? _rowFocus[i - 1].up : _rowFocus[i - 1].down)
                : null,
            onDown: i < last
                ? () => edit((s) => s.insert(i + 1, s.removeAt(i)),
                    () => i + 1 < last ? _rowFocus[i + 1].down : _rowFocus[i + 1].up)
                : null,
            // The row that takes its place, the one above, or "Add a show".
            onRemove: () => edit((s) => s.removeAt(i),
                () => last == 0 ? _addFocus : _rowFocus[i < last ? i : i - 1].remove),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TvButton(
          label: slots.isEmpty ? tr.addAShow2 : tr.addAnotherShow,
          icon: Icons.add,
          focusNode: _addFocus,
          onPressed: _addShow,
        ),
      ),
    ];
  }

  Future<void> _addShow() async {
    final key = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ShowPickerScreen()),
    );
    if (key != null) _update(() => _draft.lineup = [..._draft.lineup, LineupSlot(seriesKey: key)]);
  }

  void _setLineupMode(bool on) => _update(() {
        if (on == _lineupMode) return;
        _lineupMode = on;
        if (on) {
          // Start from the mix's shows, so a mix turns into a lineup easily.
          _draft.lineup = _setAside.isNotEmpty
              ? _setAside
              : [for (final key in _draft.source.seriesKeys) LineupSlot(seriesKey: key)];
        } else {
          _setAside = _draft.lineup;
          _draft.lineup = [];
        }
      });

  static Widget _section(GuideTheme g, String title) => Padding(
        padding: const EdgeInsets.only(top: 36, bottom: 14),
        child: Text(title, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
      );

  static int _wrap(int minute) => minute % (24 * 60);

  Future<void> _pickChannel() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _ChannelPickerScreen(selectedId: _newChannel ? null : _draft.channelId)),
    );
    if (picked == null) return;
    _update(() {
      _newChannel = picked == _ChannelPickerScreen.newChannel;
      if (!_newChannel) {
        _draft.channelId = picked;
        if (_followChannel) _copyChannel(AppScope.read(context).channelById(picked));
      }
    });
  }

  Future<void> _pickContent() async {
    final source = await Navigator.of(context).push<ChannelSource>(
      MaterialPageRoute(builder: (_) => SourcePickerScreen(initial: _draft.source)),
    );
    // The picker doesn't know the minimum rating; it stays as chosen.
    if (source != null) {
      _update(() {
        _draft.source = source.copyWith(ratingFloor: () => _draft.source.ratingFloor);
        _followChannel = false;
      });
    }
  }

  Future<void> _save() async {
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    _draft.title = _title.text.trim();
    final problem = app.blockProblem(_draft, newChannel: _newChannel, lineupMode: _lineupMode);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final oldChannelId = widget.block?.channelId;
    if (_newChannel) {
      final ch = await app.createBlockChannel(_draft.title);
      _draft.channelId = ch.id;
    }
    await app.saveBlock(_draft);
    final tuned = tuner.channel?.id;
    if (tuned != null && (tuned == _draft.channelId || tuned == oldChannelId)) await tuner.retune();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: tr.delete2(widget.block!.title),
        message: tr.theChannelGoes,
        action: tr.delete);
    if (!ok || !mounted) return;
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    await app.deleteBlock(widget.block!);
    if (tuner.channel?.id == widget.block!.channelId) await tuner.retune();
    if (mounted) Navigator.of(context).pop();
  }
}

/// The nightly new episode premiere slot (episode-premieres): on or off,
/// when, and which days. Saved changes take effect at once, as block edits
/// do.
class PremiereEditorScreen extends StatefulWidget {
  const PremiereEditorScreen({super.key});

  static String get title => tr.newEpisodePremieres;

  @override
  State<PremiereEditorScreen> createState() => _PremiereEditorScreenState();
}

class _PremiereEditorScreenState extends State<PremiereEditorScreen> {
  late PremiereSettings _draft = AppScope.read(context).settings.premieres;
  String? _error;

  void _update(PremiereSettings next) => setState(() {
        _draft = next;
        _error = null;
      });

  void _toggleDay(int d) {
    final days = {..._draft.days};
    if (!days.remove(d)) days.add(d);
    _update(_draft.copyWith(days: days));
  }

  Future<void> _save() async {
    if (_draft.enabled && _draft.days.isEmpty) {
      setState(() => _error = tr.pickAtLeast);
      return;
    }
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    await app.setPremiereSettings(_draft);
    // What's on may change from now on.
    if (tuner.channel != null) await tuner.reschedule();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvPage(
      title: PremiereEditorScreen.title,
      hints: tr.moveOkSelectEscCancel,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(100, 32, 100, 40)),
          children: [
            Text(
              tr.episodesAddedTo,
              style: g.body(26, color: g.textDim),
            ),
            _BlockEditorScreenState._section(g, tr.onTheAir),
            Align(
              alignment: Alignment.centerLeft,
              child: TvToggle(
                label: _draft.enabled ? tr.premieresAreOn : tr.premieresAreOff,
                on: _draft.enabled,
                autofocus: true,
                onPressed: () => _update(_draft.copyWith(enabled: !_draft.enabled)),
              ),
            ),
            _BlockEditorScreenState._section(g, tr.time),
            _Stepper(
              label: tr.starts,
              value: _clock(_draft.startMinute),
              onMinus: () => _update(_draft.copyWith(startMinute: _BlockEditorScreenState._wrap(_draft.startMinute - 15))),
              onPlus: () => _update(_draft.copyWith(startMinute: _BlockEditorScreenState._wrap(_draft.startMinute + 15))),
            ),
            _BlockEditorScreenState._section(g, tr.days),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var d = 1; d <= 7; d++)
                  TvToggle(
                    label: weekdayName(d),
                    on: _draft.days.contains(d),
                    onPressed: () => _toggleDay(d),
                  ),
                const SizedBox(width: 12),
                TvButton(label: tr.weekdays, onPressed: () => _update(_draft.copyWith(days: {1, 2, 3, 4, 5}))),
                TvButton(label: tr.weekends, onPressed: () => _update(_draft.copyWith(days: {6, 7}))),
                TvButton(label: tr.everyDay, onPressed: () => _update(_draft.copyWith(days: PremiereSettings.everyDay))),
              ],
            ),
            const SizedBox(height: 40),
            if (_error != null) ...[
              Text(_error!, style: g.body(28, weight: FontWeight.w600, color: g.nowLine)),
              const SizedBox(height: 20),
            ],
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TvButton(label: tr.save, icon: Icons.check, onPressed: _save),
                TvButton(label: tr.cancel, onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Starts  [−]  7:00 AM  [+]"
class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus});

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    // Upright, the label goes above the buttons.
    if (ScreenLayout.of(context).isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: g.display(30, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TvButton(label: '−', onPressed: onMinus),
              SizedBox(
                width: 220,
                child: Text(value, textAlign: TextAlign.center, style: g.display(32, weight: FontWeight.w700)),
              ),
              TvButton(label: '+', onPressed: onPlus),
            ],
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 110, child: Text(label, style: g.display(30, weight: FontWeight.w600))),
        TvButton(label: '−', onPressed: onMinus),
        SizedBox(
          width: 300,
          child: Text(value, textAlign: TextAlign.center, style: g.display(36, weight: FontWeight.w700)),
        ),
        TvButton(label: '+', onPressed: onPlus),
      ],
    );
  }
}

/// "From  [−month] [−day]  Dec 1  [+day] [+month]"
class _DateStepper extends StatelessWidget {
  const _DateStepper({required this.label, required this.value, required this.onChanged});

  final String label;
  final MonthDay value;
  final ValueChanged<MonthDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    // Upright, the label goes above the buttons, which wrap.
    if (ScreenLayout.of(context).isPortrait) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: g.display(30, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TvButton(label: tr.month2, onPressed: () => onChanged(value.addMonths(-1))),
              TvButton(label: tr.day2, onPressed: () => onChanged(value.addDays(-1))),
              Text('$value', style: g.display(32, weight: FontWeight.w700)),
              TvButton(label: tr.day, onPressed: () => onChanged(value.addDays(1))),
              TvButton(label: tr.month, onPressed: () => onChanged(value.addMonths(1))),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: g.display(30, weight: FontWeight.w600))),
        TvButton(label: tr.month2, onPressed: () => onChanged(value.addMonths(-1))),
        const SizedBox(width: 12),
        TvButton(label: tr.day2, onPressed: () => onChanged(value.addDays(-1))),
        SizedBox(
          width: 220,
          child: Text('$value', textAlign: TextAlign.center, style: g.display(36, weight: FontWeight.w700)),
        ),
        TvButton(label: tr.day, onPressed: () => onChanged(value.addDays(1))),
        const SizedBox(width: 12),
        TvButton(label: tr.month, onPressed: () => onChanged(value.addMonths(1))),
      ],
    );
  }
}

/// "1  DuckTales   [−] 2 episodes [+]   [▲] [▼] [Remove]"
class _LineupRow extends StatelessWidget {
  const _LineupRow({
    required this.number,
    required this.name,
    required this.count,
    required this.focus,
    required this.onFewer,
    required this.onMore,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final int number;
  final String name;
  final int count;
  final ({FocusNode fewer, FocusNode more, FocusNode up, FocusNode down, FocusNode remove}) focus;
  final VoidCallback? onFewer;
  final VoidCallback? onMore;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    if (ScreenLayout.of(context).isPortrait) return _portrait(g);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: g.cell, borderRadius: BorderRadius.circular(g.radius)),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text('$number', style: g.display(32, weight: FontWeight.w800, color: g.accent))),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(30, weight: FontWeight.w600)),
          ),
          TvButton(label: '−', focusNode: focus.fewer, onPressed: onFewer),
          SizedBox(
            width: 170,
            child: Text(tr.episodes2(count),
                textAlign: TextAlign.center, style: g.body(24, weight: FontWeight.w600)),
          ),
          TvButton(label: '+', focusNode: focus.more, onPressed: onMore),
          const SizedBox(width: 24),
          TvButton(label: '▲', focusNode: focus.up, onPressed: onUp),
          const SizedBox(width: 8),
          TvButton(label: '▼', focusNode: focus.down, onPressed: onDown),
          const SizedBox(width: 8),
          TvButton(label: tr.remove, icon: Icons.close, focusNode: focus.remove, onPressed: onRemove),
        ],
      ),
    );
  }

  /// Upright: the show on a line of its own, its buttons wrapping below.
  Widget _portrait(GuideTheme g) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: BoxDecoration(color: g.cell, borderRadius: BorderRadius.circular(g.radius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: 48, child: Text('$number', style: g.display(32, weight: FontWeight.w800, color: g.accent))),
                Expanded(
                  child: Text(name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(30, weight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TvButton(label: '−', focusNode: focus.fewer, onPressed: onFewer),
                Text(tr.episodes2(count), style: g.body(24, weight: FontWeight.w600)),
                TvButton(label: '+', focusNode: focus.more, onPressed: onMore),
                const SizedBox(width: 16),
                TvButton(label: '▲', focusNode: focus.up, onPressed: onUp),
                TvButton(label: '▼', focusNode: focus.down, onPressed: onDown),
                TvButton(label: tr.remove, icon: Icons.close, focusNode: focus.remove, onPressed: onRemove),
              ],
            ),
          ],
        ),
      );
}

/// "7:30 AM  DuckTales / S1 · E4 · Duck Blind" in the next-airing preview.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.program});

  final ScheduledProgram program;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(formatTime(program.start), style: g.display(24, weight: FontWeight.w700))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(24, weight: FontWeight.w600)),
                Text(program.subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(20, color: g.textDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick a show for a lineup slot. Pops with its series key.
class _ShowPickerScreen extends StatelessWidget {
  const _ShowPickerScreen();

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final library = AppScope.of(context).library;
    final series = [
      for (final s in library.series)
        if (library.episodesBySeries[s.key]?.isNotEmpty ?? false) s,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return TvPage(
      title: tr.addAShow2,
      hints: tr.moveOkAdd,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(120, 32, 120, 32)),
          children: [
            for (final (i, s) in series.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TvFocusable(
                  autofocus: i == 0,
                  onPressed: () => Navigator.of(context).pop(s.key),
                  builder: (context, focused) => AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: focused ? g.cellBorder : g.cell,
                      borderRadius: BorderRadius.circular(g.radius),
                      border: Border.all(color: focused ? g.focus : Colors.transparent, width: 4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(s.year == null ? s.name : '${s.name} (${s.year})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: g.display(30, weight: FontWeight.w600)),
                        ),
                        Text(tr.episodes(library.episodesBySeries[s.key]!.length),
                            style: g.body(22, color: g.textDim)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pick the channel a block airs on. Pops with a channel id, or
/// [newChannel] for a channel of the block's own.
class _ChannelPickerScreen extends StatelessWidget {
  const _ChannelPickerScreen({required this.selectedId});

  static const newChannel = '__new__';

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final channels = app.allChannels;
    final selectedIndex = channels.indexWhere((c) => c.id == selectedId);
    return TvPage(
      title: tr.chooseAChannel2,
      hints: tr.moveOkChoose,
      onBack: () => Navigator.of(context).pop(),
      child: FocusTraversalGroup(
        child: ListView(
          padding: ScreenLayout.of(context).pagePadding(const EdgeInsets.fromLTRB(120, 32, 120, 32)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TvButton(
                label: tr.aNewChannelJust,
                icon: Icons.add,
                autofocus: selectedIndex < 0,
                onPressed: () => Navigator.of(context).pop(newChannel),
              ),
            ),
            const SizedBox(height: 8),
            Text(tr.aNewChannel,
                style: g.body(24, color: g.textDim)),
            const SizedBox(height: 28),
            for (final (i, ch) in channels.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TvFocusable(
                  autofocus: i == selectedIndex,
                  onPressed: () => Navigator.of(context).pop(ch.id),
                  builder: (context, focused) => AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 84,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: focused ? g.cellBorder : g.cell,
                      borderRadius: BorderRadius.circular(g.radius),
                      border: Border.all(color: focused ? g.focus : Colors.transparent, width: 4),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text('${ch.number}',
                              style: g.display(38, weight: FontWeight.w800, color: g.accent)),
                        ),
                        ChannelLogo(icon: ch.icon, size: 56, width: 90, fallbackText: ch.displayName),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(ch.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: g.display(30, weight: FontWeight.w600)),
                        ),
                        if (ch.id == selectedId) Icon(Icons.check, color: g.accent, size: 36),
                        if (ch.hidden) Icon(Icons.visibility_off, color: g.textDim, size: 28),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
