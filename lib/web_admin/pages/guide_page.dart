import 'package:flutter/material.dart';

import '../../channels/channel.dart';
import '../../ui/format.dart';
import '../app.dart';
import '../widgets/channel_icon.dart';
import '../widgets/common.dart';

/// What airs on each channel, read-only, at most 24 hours ahead: channel
/// rows over a time axis on wide screens, one channel's list on phones.
class GuidePage extends StatefulWidget {
  const GuidePage({super.key, required this.profileId});
  final String profileId;

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  /// Hours shown at once on a wide screen.
  static const span = 3;

  late final DateTime _start = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour);
  }();
  int _offset = 0;
  String? _channel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 720;
        final from = _start.add(Duration(hours: wide ? _offset : 0));
        final hours = wide ? span : 24;
        return DataView<Map<String, Object?>>(
          key: ValueKey('$wide $_offset'),
          load: () async => (await context.api.get('profiles/${widget.profileId}/guide',
              {'from': from.toUtc().toIso8601String(), 'hours': '$hours'}))! as Map<String, Object?>,
          builder: (context, data, _) {
            final channels = (data['channels'] as List).cast<Map<String, Object?>>();
            return wide ? _grid(context, channels, from, hours) : _list(context, channels);
          },
        );
      });

  Widget _grid(BuildContext context, List<Map<String, Object?>> channels, DateTime from, int hours) {
    final scheme = Theme.of(context).colorScheme;
    final to = from.add(Duration(hours: hours));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Semantics(header: true, child: Text('Guide', style: Theme.of(context).textTheme.headlineSmall)),
          ),
          IconButton(
            tooltip: 'Earlier',
            icon: const Icon(Icons.chevron_left),
            onPressed: _offset == 0 ? null : () => setState(() => _offset -= span),
          ),
          Text('${formatDate(from)}  ${formatRange(from, to)}'),
          IconButton(
            tooltip: 'Later',
            icon: const Icon(Icons.chevron_right),
            onPressed: _offset + span >= 24 ? null : () => setState(() => _offset += span),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, size) {
            const label = 180.0;
            final perMinute = (size.maxWidth - label) / (hours * 60);
            double x(DateTime t) => t.difference(from).inSeconds / 60 * perMinute;
            return Column(children: [
              SizedBox(
                height: 28,
                child: Stack(children: [
                  for (var m = 0; m < hours * 60; m += 30)
                    Positioned(
                      left: label + m * perMinute,
                      child: Text(formatTime(from.add(Duration(minutes: m))), style: Theme.of(context).textTheme.labelSmall),
                    ),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (context, i) {
                    final c = channels[i];
                    final airings = (c['airings'] as List).cast<Map<String, Object?>>();
                    return SizedBox(
                      height: 56,
                      child: Stack(children: [
                        Positioned(
                          left: 0,
                          width: label - 4,
                          top: 2,
                          bottom: 2,
                          child: Row(children: [
                            ChannelIconView(
                              icon: ChannelIcon.fromJson((c['icon'] as Map).cast<String, Object?>()),
                              profileId: widget.profileId,
                              channelId: c['id'] as String,
                              size: 28,
                              fallbackText: c['name'] as String,
                            ),
                            const SizedBox(width: 4),
                            Expanded(child: Text('${c['number']} ${c['name']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                        for (final a in airings)
                          () {
                            final start = DateTime.parse(a['start'] as String).toLocal();
                            final end = DateTime.parse(a['end'] as String).toLocal();
                            final left = x(start).clamp(0.0, size.maxWidth - label);
                            final right = x(end).clamp(0.0, size.maxWidth - label);
                            return Positioned(
                              left: label + left,
                              width: (right - left - 2).clamp(0.0, double.infinity),
                              top: 2,
                              bottom: 2,
                              child: Tooltip(
                                message: _describe(a, start, end),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: a['offAir'] == true ? scheme.surfaceContainerLow : scheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    a['title'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
                                  ),
                                ),
                              ),
                            );
                          }(),
                      ]),
                    );
                  },
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _list(BuildContext context, List<Map<String, Object?>> channels) {
    if (channels.isEmpty) return const PageBody(title: 'Guide', children: [Text('No channels yet.')]);
    final selected = channels.firstWhere((c) => c['id'] == _channel, orElse: () => channels.first);
    final airings = (selected['airings'] as List).cast<Map<String, Object?>>();
    return PageBody(title: 'Guide', children: [
      DropdownButtonFormField<String>(
        initialValue: selected['id'] as String,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Channel'),
        items: [
          for (final c in channels)
            DropdownMenuItem(value: c['id'] as String, child: Text('${c['number']}  ${c['name']}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (id) => setState(() => _channel = id),
      ),
      const SizedBox(height: 8),
      for (final a in airings)
        () {
          final start = DateTime.parse(a['start'] as String).toLocal();
          final end = DateTime.parse(a['end'] as String).toLocal();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(width: 72, child: Text(formatTime(start))),
            title: Text(a['title'] as String),
            subtitle: Text(_describe(a, start, end)),
          );
        }(),
    ]);
  }

  static String _describe(Map<String, Object?> a, DateTime start, DateTime end) {
    final breaks = a['breaks'] as Map?;
    final mids = breaks?['mids'] as int? ?? 0;
    return [
      formatRange(start, end),
      if ((a['detail'] as String?)?.isNotEmpty == true) a['detail'] as String,
      if (a['block'] != null) a['block'] as String,
      if (a['premiere'] == true) 'New episode',
      if (a['songs'] != null) '${a['songs']} songs',
      if (breaks != null) mids > 0 ? '$mids break${mids == 1 ? '' : 's'} inside' : 'Breaks between programs',
    ].join(' · ');
  }
}
