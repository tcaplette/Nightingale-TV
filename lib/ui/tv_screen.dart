import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_exit.dart';
import '../app_scope.dart';
import '../channels/channel.dart';
import '../channels/schedule.dart';
import '../platform/platform_info.dart';
import '../playback/playback_diagnostics.dart';
import '../playback/tuner.dart';
import '../theme/tv_theme.dart';
import 'format.dart';
import 'guide_view.dart';
import 'menu_screen.dart';
import 'widgets/broadcast_cards.dart';
import 'widgets/channel_logo.dart';
import 'widgets/tv_focus.dart';

/// Main screen: full-screen TV with channel banner and number entry; the
/// guide opens on top of it.
class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  /// Android: shown after Back on the TV screen.
  static const exitPrompt = 'Press Back again to exit';

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  static const _bannerDuration = Duration(seconds: 5);
  static const _digitTimeout = Duration(milliseconds: 1600);
  static const _exitWindow = Duration(seconds: 3);

  final _focus = FocusNode(debugLabel: 'tv');
  bool _guideOpen = false;
  bool _banner = false;
  Timer? _bannerTimer;
  String _digits = '';
  Timer? _digitTimer;
  String? _toast;
  Timer? _toastTimer;

  /// Android: Back was pressed once; another within [_exitWindow] quits.
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _powerOn());
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _digitTimer?.cancel();
    _toastTimer?.cancel();
    _exitTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  /// Like turning on a TV: back to the last channel watched.
  void _powerOn() {
    PlaybackDiagnostics.mark('TV screen shown');
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    final channels = app.channels;
    if (channels.isEmpty) {
      setState(() => _guideOpen = true);
      return;
    }
    if (tuner.channel == null) {
      final last = channels.where((c) => c.id == app.settings.lastChannelId).firstOrNull;
      tuner.tune(last ?? channels.first);
    }
    _showBanner();
  }

  void _showBanner() {
    _bannerTimer?.cancel();
    setState(() => _banner = true);
    _bannerTimer = Timer(_bannerDuration, () {
      if (mounted) setState(() => _banner = false);
    });
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _surf(Future<void> Function() action) async {
    _digits = '';
    await action();
    _showBanner();
  }

  void _typeDigit(int digit) {
    _digitTimer?.cancel();
    // Keep the last three digits typed, like a cable box.
    final typed = '$_digits$digit';
    setState(() => _digits = typed.length > 3 ? typed.substring(typed.length - 3) : typed);
    _digitTimer = Timer(_digitTimeout, _commitDigits);
  }

  Future<void> _commitDigits() async {
    _digitTimer?.cancel();
    final number = int.tryParse(_digits);
    setState(() => _digits = '');
    if (number == null) return;
    final ok = await AppScope.tunerOf(context).tuneNumber(number);
    if (!mounted) return;
    if (ok) {
      _showBanner();
    } else {
      _showToast('There is no channel $number');
    }
  }

  void _openGuide() => setState(() => _guideOpen = true);

  /// Android's Back on the TV screen: the first asks, the second quits.
  void _back() {
    if (_digits.isNotEmpty) {
      _digitTimer?.cancel();
      setState(() => _digits = '');
    } else if (_exitTimer?.isActive ?? false) {
      _exitTimer!.cancel();
      final tuner = AppScope.tunerOf(context);
      quitApp(beforeClosing: tuner.stop);
    } else {
      _showToast(TvScreen.exitPrompt);
      _exitTimer = Timer(_exitWindow, () {});
    }
  }

  /// Anything but a second Back cancels the exit prompt.
  void _cancelExit() {
    if (!(_exitTimer?.isActive ?? false)) return;
    _exitTimer!.cancel();
    if (_toast == TvScreen.exitPrompt) {
      _toastTimer?.cancel();
      setState(() => _toast = null);
    }
  }

  void _closeGuide() {
    setState(() => _guideOpen = false);
    _focus.requestFocus();
    _showBanner();
  }

  void _watch(Channel ch) {
    final tuner = AppScope.tunerOf(context);
    if (tuner.channel?.id != ch.id) tuner.tune(ch);
    _closeGuide();
  }

  Future<void> _openMenu() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MenuScreen()));
    if (!mounted) return;
    // Channels may have been edited, hidden or renumbered.
    final app = AppScope.read(context);
    final tuner = AppScope.tunerOf(context);
    final current = tuner.channel;
    if (current != null && !app.channels.any((c) => c.id == current.id)) {
      if (app.channels.isNotEmpty) {
        await tuner.tune(app.channels.first);
      } else {
        await tuner.stop();
      }
    }
    if (_guideOpen) {
      setState(() {});
    } else {
      _focus.requestFocus();
    }
  }

  static int? _digitFor(LogicalKeyboardKey key) {
    const keys = [
      LogicalKeyboardKey.digit0, LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6, LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad0, LogicalKeyboardKey.numpad1, LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3, LogicalKeyboardKey.numpad4, LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6, LogicalKeyboardKey.numpad7, LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = keys.indexOf(key);
    if (i >= 0) return i;
    final n = numpad.indexOf(key);
    return n >= 0 ? n : null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final tuner = AppScope.tunerOf(context);
    final key = event.logicalKey;
    if (PlatformInfo.isAndroid) {
      // Back leaves the app, as Android expects (Escape from a keyboard
      // still opens the guide). Held down, it doesn't repeat into quitting.
      if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.browserBack) {
        if (event is KeyDownEvent) _back();
        return KeyEventResult.handled;
      }
      _cancelExit();
      // The remote's own Guide and Last Channel buttons.
      if (key == LogicalKeyboardKey.guide) {
        _openGuide();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaLast) {
        _surf(tuner.lastChannel);
        return KeyEventResult.handled;
      }
    }
    final digit = _digitFor(key);
    if (digit != null) {
      _typeDigit(digit);
    } else if (_digits.isNotEmpty && isSelectKey(key)) {
      _commitDigits();
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.channelUp) {
      _surf(tuner.channelUp);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.channelDown) {
      _surf(tuner.channelDown);
    } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.keyL) {
      _surf(tuner.lastChannel);
    } else if (isSelectKey(key) ||
        key == LogicalKeyboardKey.keyG ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.goBack) {
      _openGuide();
    } else if (key == LogicalKeyboardKey.keyI ||
        key == LogicalKeyboardKey.info ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _showBanner();
    } else if (key == LogicalKeyboardKey.keyC || key == LogicalKeyboardKey.closedCaptionToggle) {
      tuner.toggleCaptions().then((_) => _showToast(tuner.captions ? 'Captions on' : 'Captions off'));
    } else if (key == LogicalKeyboardKey.keyM || key == LogicalKeyboardKey.contextMenu) {
      _openMenu();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tuner = AppScope.tunerOf(context);
    if (_guideOpen) {
      return GuideView(onWatch: _watch, onClose: _closeGuide, onMenu: _openMenu);
    }
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        // Moving the air mouse brings up the banner and the on-screen
        // Guide and Menu buttons, like waking a cable box.
        onHover: (_) => _showBanner(),
        child: GestureDetector(
        onTap: () {
          _cancelExit();
          _openGuide();
        },
        onSecondaryTap: _openMenu,
        // Touch: long-press is right-click.
        onLongPress: PlatformInfo.isAndroid ? _openMenu : null,
        child: ColoredBox(
          color: Colors.black,
          child: ListenableBuilder(
            listenable: tuner,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                tuner.media.buildVideo(),
                if (tuner.status == TunerStatus.standby)
                  StatusCard(
                    icon: Icons.schedule,
                    title: 'PLEASE STAND BY',
                    message: tuner.program == null
                        ? null
                        : 'Up next at ${formatTime((tuner.segment ?? tuner.program!).end)}',
                  ),
                if (tuner.status == TunerStatus.offAir)
                  StatusCard(
                    icon: Icons.tv_off,
                    title: 'OFF THE AIR',
                    message: switch (_backOnAir(context, tuner)) {
                      final b? => 'Back on the air ${b.when} with ${b.title}',
                      null => null,
                    },
                  ),
                if (tuner.status == TunerStatus.error)
                  StatusCard(
                    icon: Icons.signal_cellular_connected_no_internet_0_bar,
                    title: 'NO SIGNAL',
                    message: [
                      if (tuner.error != null) tuner.error!,
                      if (tuner.program != null)
                        'Trying again at ${formatTime((tuner.segment ?? tuner.program!).end)}',
                    ].join('\n'),
                  ),
                if (tuner.changingChannel || _digits.isNotEmpty)
                  Positioned(
                    top: 60,
                    right: 90,
                    child: ChannelNumberOsd(
                        text: _digits.isNotEmpty ? '${_digits}_' : '${tuner.channel?.number ?? ''}'),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  bottom: _banner && tuner.channel != null ? 0 : -260,
                  child: tuner.channel == null
                      ? const SizedBox.shrink()
                      : _ChannelBanner(
                          channel: tuner.channel!,
                          program: tuner.program,
                          inBreak: tuner.inBreak,
                          next: tuner.program == null
                              ? null
                              : AppScope.read(context).scheduleFor(tuner.channel!)?.next(tuner.program!),
                          backOnAir: tuner.program?.isOffAir ?? false ? _backOnAir(context, tuner)?.when : null,
                        ),
                ),
                if ((tuner.status == TunerStatus.playing ? AppScope.read(context).scheduleFor(tuner.channel!) : null)
                    case final schedule? when tuner.program != null && tuner.segment != null)
                  Positioned(
                    right: 90,
                    bottom: 70,
                    child: _UpNext(
                      program: tuner.program!,
                      segment: tuner.segment!,
                      next: schedule.next(tuner.program!),
                      lastPart: schedule.isLastPart(tuner.program!, tuner.segment!),
                      hidden: _banner,
                    ),
                  ),
                if (_toast != null)
                  Positioned(top: 60, left: 0, right: 0, child: Center(child: _Toast(_toast!))),
                Positioned(
                  top: 48,
                  left: 60,
                  child: IgnorePointer(
                    ignoring: !_banner,
                    child: AnimatedOpacity(
                      opacity: _banner ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Row(
                        children: [
                          TvPointerButton(label: 'Guide', icon: Icons.grid_view, onPressed: _openGuide),
                          const SizedBox(width: 16),
                          TvPointerButton(label: 'Menu', icon: Icons.settings, onPressed: _openMenu),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// When an off-air channel's next block starts: "SAT DEC 5 7:00 AM", or
/// just the time if it's within the day.
({String when, String title})? _backOnAir(BuildContext context, Tuner tuner) {
  final ch = tuner.channel;
  if (ch == null) return null;
  final now = DateTime.now();
  final next = AppScope.read(context).scheduleFor(ch)?.nextBlockAiring(now);
  if (next == null) return null;
  final when = next.start.difference(now) < const Duration(hours: 20)
      ? formatTime(next.start)
      : '${formatDate(next.start)} ${formatTime(next.start)}';
  return (when: when, title: next.title);
}

/// What the banner says during a break.
const commercialBreakLabel = 'Commercial break';

class _ChannelBanner extends StatelessWidget {
  const _ChannelBanner(
      {required this.channel, required this.program, required this.next, this.inBreak = false, this.backOnAir});

  final Channel channel;
  final ScheduledProgram? program;

  /// A commercial break in [program] is on.
  final bool inBreak;
  final ScheduledProgram? next;

  /// When the channel comes back, shown instead of "Next" while it's off
  /// the air.
  final String? backOnAir;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final now = DateTime.now();
    final p = program;
    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(90, 28, 90, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [g.backgroundTop.withValues(alpha: 0.0), g.backgroundBottom.withValues(alpha: 0.95)],
          stops: const [0, 0.35],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(color: g.accent, borderRadius: BorderRadius.circular(g.radius * 2)),
            alignment: Alignment.center,
            child: Text('${channel.number}', style: g.display(84, weight: FontWeight.w800, color: g.onFocus)),
          ),
          const SizedBox(width: 28),
          ChannelLogo(icon: channel.icon, size: 120, width: 200, fallbackText: channel.name),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    [channel.name, if (p?.blockTitle != null) p!.blockTitle!]
                        .join('   ·   ')
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.display(28, weight: FontWeight.w700, color: g.accent)),
                Text(p?.title ?? 'Tuning…',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(60, weight: FontWeight.w800)),
                if (p != null)
                  Text('${inBreak ? commercialBreakLabel : p.subtitle}   ·   ${formatRange(p.start, p.end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: inBreak ? g.body(26, weight: FontWeight.w600, color: g.accent) : g.body(26, color: g.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 32),
          if (p != null)
            SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatTime(now), style: g.display(44, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (!p.isOffAir) ...[
                    LinearProgressIndicator(
                      value: p.offsetAt(now).inSeconds / p.duration.inSeconds.clamp(1, 1 << 30),
                      minHeight: 8,
                      color: g.accent,
                      backgroundColor: g.cell,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    p.isOffAir
                        ? (backOnAir == null ? 'Off the air' : 'Back on $backOnAir')
                        : next == null
                            ? '${formatMinutes(p.end.difference(now))} left'
                            : 'Next ${formatTime(next!.start)}: ${next!.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: g.body(24, color: g.textDim),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// When the "Up next" card is up during [segment] of [program]: from a
/// minute before the show ends, for 15 seconds, in the part it ends in
/// ([lastPart]: its last one, or the one a programming block cuts off).
/// Null when there's nothing to announce.
({DateTime from, DateTime to})? upNextWindow(
    ScheduledProgram program, ScheduledProgram segment, ScheduledProgram? next, {required bool lastPart}) {
  final item = program.item;
  if (item == null || next == null || next.isOffAir || segment.isBreak || segment.item?.id != item.id) return null;
  if (item.runtime < _UpNext.minRuntime || !lastPart) return null;
  final from = segment.end.subtract(_UpNext.lead);
  return (from: from, to: from.add(_UpNext.showFor));
}

/// The "Up next" card that slides in near the end of a show, like a cable
/// network's end-credits promo. When the next program starts a programming
/// block, it announces the block.
class _UpNext extends StatefulWidget {
  const _UpNext(
      {required this.program, required this.segment, required this.next, required this.lastPart, required this.hidden});

  /// When it comes up: this long before the show ends…
  static const lead = Duration(seconds: 60);

  /// …for this long.
  static const showFor = Duration(seconds: 15);

  /// Too short a program to interrupt (cartoon shorts, music videos).
  static const minRuntime = Duration(minutes: 5);

  final ScheduledProgram program;

  /// What's playing: the program, a part of it, or a break.
  final ScheduledProgram segment;
  final ScheduledProgram? next;

  /// [segment] is the last of the show to air.
  final bool lastPart;

  /// The channel banner is up, and already says what's next.
  final bool hidden;

  @override
  State<_UpNext> createState() => _UpNextState();
}

class _UpNextState extends State<_UpNext> {
  late final Timer _tick;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _check();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void didUpdateWidget(_UpNext old) {
    super.didUpdateWidget(old);
    _check();
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _check() {
    final w = upNextWindow(widget.program, widget.segment, widget.next, lastPart: widget.lastPart);
    final now = DateTime.now();
    final visible = w != null && !widget.hidden && !now.isBefore(w.from) && now.isBefore(w.to);
    if (visible != _visible && mounted) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    final n = widget.next;
    final block = n?.blockTitle != null && n!.blockTitle != widget.program.blockTitle ? n.blockTitle : null;
    return IgnorePointer(
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(1.3, 0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: n == null
              ? const SizedBox.shrink()
              : Container(
                  width: 560,
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                  decoration: BoxDecoration(
                    color: g.panel.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(g.radius * 2),
                    border: Border(left: BorderSide(color: g.accent, width: 8)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UP NEXT  ·  ${formatTime(n.start)}',
                          style: g.display(24, weight: FontWeight.w800, color: g.accent)),
                      const SizedBox(height: 4),
                      Text(block ?? n.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: g.display(40, weight: FontWeight.w800)),
                      Text(
                        block != null ? 'Starting with ${n.title}' : n.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: g.body(24, color: g.textDim),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
      decoration: BoxDecoration(
        color: g.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(g.radius * 2),
        border: Border.all(color: g.accent, width: 2),
      ),
      child: Text(message, style: g.display(36, weight: FontWeight.w600)),
    );
  }
}
