import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../commercials/analysis/media_analyzer.dart';
import '../commercials/break_plan.dart';
import '../commercials/commercial_pool.dart';
import '../platform/platform_info.dart';
import '../theme/tv_theme.dart';
import 'break_plan_editor_screen.dart';
import 'pool_editor_screen.dart';
import 'widgets/adaptive.dart';
import 'widgets/screen_layout.dart';
import 'widgets/tv_focus.dart';

/// The main break plan (Off, Automatic or Custom), the commercial pools,
/// and how far splitting and break-finding have got.
class CommercialsScreen extends StatelessWidget {
  const CommercialsScreen({super.key});

  /// Shown when a reel can't be split for lack of ffmpeg.
  static const ffmpegWarning = 'Install ffmpeg to split long commercial videos';

  /// Shown instead of [ffmpegWarning] on Android, which can't run ffmpeg.
  static const androidFfmpegNote = 'Long commercial videos without chapters can\'t be split on this device';

  /// What the screen says when reels can't be split for lack of ffmpeg,
  /// with [waiting] of them waiting.
  static String ffmpegMissingText(int waiting) {
    final count = waiting > 0 ? ' ($waiting waiting).' : '.';
    return PlatformInfo.isAndroid
        ? '$androidFfmpegNote$count'
        : '$ffmpegWarning$count Break points also land more naturally with it.';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = context.guide;
    final plan = app.settings.commercialPlan;
    final pools = app.settings.commercialPools;
    final overrides = app.allChannels.where((c) => c.commercialPlan != null).length;

    Future<void> setPlan(BreakPlan p) async {
      final tuner = AppScope.tunerOf(context);
      await app.setGlobalPlan(p);
      // What's playing plays on; the new breaks start after it.
      await tuner.reschedule();
    }

    Future<void> editRoles() async {
      final roles = await Navigator.of(context).push<CustomRoles>(MaterialPageRoute(
          builder: (_) => BreakPlanEditorScreen(initial: plan.roles, title: 'Break settings')));
      if (roles != null) await setPlan(BreakPlan(mode: BreakMode.custom, roles: roles));
    }

    Future<void> openPool(CommercialPool pool) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PoolEditorScreen(pool: pool)));

    return TvPage(
      title: 'Commercials',
      hints: '▲▼◀▶ Move    OK Select    ESC Back',
      onBack: () => Navigator.of(context).pop(),
      child: AdaptiveColumns(
                mainPadding: const EdgeInsets.fromLTRB(100, 40, 40, 40),
                sideWidth: 640,
                side: _HowItWorks(plan: plan),
                main: [
                  Text('COMMERCIAL BREAKS', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final mode in BreakMode.values)
                        TvToggle(
                          label: mode.label,
                          radio: true,
                          autofocus: mode == plan.mode,
                          on: mode == plan.mode,
                          onPressed: () => setPlan(plan.withMode(mode)),
                        ),
                      if (plan.mode == BreakMode.custom)
                        TvButton(label: 'Break settings…', icon: Icons.tune, onPressed: editRoles),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_summary(app, plan), style: g.body(24, color: g.textDim)),
                  if (overrides > 0)
                    Text(
                      '$overrides channel${overrides == 1 ? ' has' : 's have'} its own setting (Channels & icons).',
                      style: g.body(24, color: g.textDim),
                    ),
                  const SizedBox(height: 40),
                  Text('POOLS', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 6),
                  Text(
                    'Pick the Jellyfin folders that hold commercials and bumpers. Their videos leave your '
                    'regular channels and fill the breaks instead.',
                    style: g.body(24, color: g.textDim),
                  ),
                  const SizedBox(height: 16),
                  for (final pool in pools)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TvButton(
                        label: '${pool.name}  ·  ${_poolDetail(app, pool)}',
                        icon: Icons.video_library,
                        expand: true,
                        onPressed: () => openPool(pool),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvButton(
                      label: 'New pool',
                      icon: Icons.add,
                      onPressed: () async {
                        final pool = await app.createPool();
                        if (context.mounted) await openPool(pool);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (app.refreshing)
                    Text(app.syncStatus, style: g.body(26, weight: FontWeight.w600, color: g.accent))
                  else if (app.syncError != null)
                    Text('Last scan failed: ${app.syncError}', style: g.body(24, color: g.nowLine)),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<AnalysisProgress>(
                    valueListenable: app.analysisProgress,
                    builder: (context, progress, _) => _AnalysisStatus(progress: progress),
                  ),
                ],
      ),
    );
  }

  static String _clips(int n) => '$n clip${n == 1 ? '' : 's'}';

  /// What breaks are doing, or why they aren't happening.
  static String _summary(AppState app, BreakPlan plan) {
    final pools = app.settings.commercialPools;
    final clips = app.catalog.clipsFor(null).length;
    if (plan.isOff) {
      return clips == 0 ? 'Breaks are off.' : 'Breaks are off. ${_clips(clips)} ready in your pools.';
    }
    if (pools.isEmpty) return 'Breaks start once a pool has clips. Make a pool below.';
    if (!app.hasClipsFor(plan)) {
      final waiting = app.analysisProgress.value;
      return waiting.reelsTotal > waiting.reelsDone
          ? 'Breaks start once a pool has clips. Its long videos are being split now.'
          : 'Breaks start once a pool has clips. Add folders with videos to a pool.';
    }
    final used = pools.where((p) => app.catalog.hasClips(p.id)).length;
    return '${_clips(clips)} from $used pool${used == 1 ? '' : 's'}.';
  }

  static String _poolDetail(AppState app, CommercialPool pool) {
    final folders = pool.roots.length;
    return '$folders folder${folders == 1 ? '' : 's'}  ·  ${_clips(app.catalog.clipsFor(pool.id).length)}';
  }
}

class _AnalysisStatus extends StatelessWidget {
  const _AnalysisStatus({required this.progress});

  final AnalysisProgress progress;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final p = progress;
    final lines = <String>[
      if (p.reelsTotal > 0) 'Long videos split: ${p.reelsDone} of ${p.reelsTotal}',
      if (p.programsTotal > 0) 'Programs with break points: ${p.programsDone} of ${p.programsTotal}',
      if (p.failed > 0) '${p.failed} could not be analyzed (they\'re tried again if the file changes)',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isNotEmpty || p.busy) ...[
          Text('ANALYSIS', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
          const SizedBox(height: 8),
          for (final l in lines) Text(l, style: g.body(24)),
          if (p.current != null)
            Text('Working on ${p.current}…', maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(24, color: g.textDim)),
        ],
        if (p.ffmpegMissing) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.warning_amber, size: 32, color: g.nowLine),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  CommercialsScreen.ffmpegMissingText(p.reelsNeedingFfmpeg),
                  style: g.body(24, color: g.nowLine),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.plan});

  final BreakPlan plan;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final lines = switch (plan.mode) {
      BreakMode.off => const [
          'Programs play back to back, with no breaks.',
          'Pick Automatic for breaks like broadcast TV, or Custom to set them up yourself.',
        ],
      BreakMode.automatic => const [
          'Every show fills a half-hour slot (an hour or more for long ones), so the guide stays on the clock.',
          'A short bumper before the show, a break every 10 minutes inside it (12 for movies), at act breaks '
              'when they can be found, and the rest after it.',
          'Ads shrink to fit the slot, and no break runs over 5 minutes.',
        ],
      BreakMode.custom => const [
          'Choose how long each break is, how often shows break, and which pool each break draws from.',
          'With a tail, slots are padded out to the clock.',
        ],
    };
    final portrait = ScreenLayout.of(context).isPortrait;
    return Container(
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
          Text('HOW BREAKS WORK', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
          const SizedBox(height: 16),
          for (final line in [...lines, 'The same ads play for everyone, every time.', 'Commercials never show up in your Jellyfin watch history.'])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text('•  $line', style: g.body(24, color: g.textDim)),
            ),
        ],
      ),
    );
  }
}
