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
import '../l10n/tr.dart';

/// The main break plan (Off, Automatic or Custom), the commercial pools,
/// and how far splitting and break-finding have got.
class CommercialsScreen extends StatelessWidget {
  const CommercialsScreen({super.key});

  /// Shown when a reel can't be split for lack of ffmpeg.
  static String get ffmpegWarning => tr.installFfmpegTo;

  /// Shown instead of [ffmpegWarning] on Android, which can't run ffmpeg.
  static String get androidFfmpegNote => tr.longCommercialVideos;

  /// What the screen says when reels can't be split for lack of ffmpeg,
  /// with [waiting] of them waiting.
  static String ffmpegMissingText(int waiting) {
    final count = waiting > 0 ? tr.waiting(waiting) : '.';
    return PlatformInfo.isAndroid
        ? '$androidFfmpegNote$count'
        : tr.breakPointsAlso(ffmpegWarning, count);
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
          builder: (_) => BreakPlanEditorScreen(initial: plan.roles, title: tr.breakSettings2)));
      if (roles != null) await setPlan(BreakPlan(mode: BreakMode.custom, roles: roles));
    }

    Future<void> openPool(CommercialPool pool) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PoolEditorScreen(pool: pool)));

    return TvPage(
      title: tr.commercials,
      hints: tr.moveOkSelectEsc,
      onBack: () => Navigator.of(context).pop(),
      child: AdaptiveColumns(
                mainPadding: const EdgeInsets.fromLTRB(100, 40, 40, 40),
                sideWidth: 640,
                side: _HowItWorks(plan: plan),
                main: [
                  Text(tr.commercialBreaks, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
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
                        TvButton(label: tr.breakSettings, icon: Icons.tune, onPressed: editRoles),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_summary(app, plan), style: g.body(24, color: g.textDim)),
                  if (overrides > 0)
                    Text(
                      tr.channelOverrides(overrides),
                      style: g.body(24, color: g.textDim),
                    ),
                  const SizedBox(height: 40),
                  Text(tr.pools, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                  const SizedBox(height: 6),
                  Text(
                    tr.pickTheFolders,
                    style: g.body(24, color: g.textDim),
                  ),
                  const SizedBox(height: 16),
                  for (final pool in pools)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TvButton(
                        label: '${pool.name}  ·  ${pool.kind.label}  ·  ${_poolDetail(app, pool)}',
                        icon: Icons.video_library,
                        expand: true,
                        onPressed: () => openPool(pool),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvButton(
                      label: tr.newPool,
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
                    Text(tr.lastScanFailed('${app.syncError}'), style: g.body(24, color: g.nowLine)),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<AnalysisProgress>(
                    valueListenable: app.analysisProgress,
                    builder: (context, progress, _) => _AnalysisStatus(progress: progress),
                  ),
                ],
      ),
    );
  }

  static String _clips(int n) => tr.clips3(n);

  /// What breaks are doing, or why they aren't happening.
  static String _summary(AppState app, BreakPlan plan) {
    final pools = app.settings.commercialPools;
    final clips = app.catalog.clipsFor(null).length;
    if (plan.isOff) {
      return clips == 0 ? tr.breaksAreOff2 : tr.breaksAreOff(_clips(clips));
    }
    if (pools.isEmpty) return tr.breaksStartOnceAPool;
    if (!app.hasClipsFor(plan)) {
      final waiting = app.analysisProgress.value;
      return waiting.reelsTotal > waiting.reelsDone
          ? tr.breaksStartOnceA
          : tr.breaksStartOnce;
    }
    final used = pools.where((p) => app.catalog.hasClips(p.id)).length;
    return tr.fromCommercialPools(_clips(clips), used);
  }

  static String _poolDetail(AppState app, CommercialPool pool) {
    final folders = pool.roots.length;
    return tr.folders(folders, _clips(app.catalog.clipsFor(pool.id).length));
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
      if (p.reelsTotal > 0) tr.longVideosSplit(p.reelsDone, p.reelsTotal),
      if (p.programsTotal > 0) tr.programsWithBreak(p.programsDone, p.programsTotal),
      if (p.failed > 0) tr.couldNotBe(p.failed),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isNotEmpty || p.busy) ...[
          Text(tr.analysis, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
          const SizedBox(height: 8),
          for (final l in lines) Text(l, style: g.body(24)),
          if (p.current != null)
            Text(tr.workingOn('${p.current}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(24, color: g.textDim)),
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
      BreakMode.off => [
          tr.programsPlayBack,
          tr.pickAutomaticFor,
        ],
      BreakMode.automatic => [
          tr.everyShowFills,
          tr.aShortBreak,
          tr.adsShrinkTo,
        ],
      BreakMode.custom => [
          tr.chooseHowLong,
          tr.withATail,
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
          Text(tr.howBreaksWork, style: g.display(26, weight: FontWeight.w800, color: g.accent)),
          const SizedBox(height: 16),
          for (final line in [...lines, tr.bumperPoolsClips, tr.theSameAds, tr.commercialsNeverShow])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text('•  $line', style: g.body(24, color: g.textDim)),
            ),
        ],
      ),
    );
  }
}
