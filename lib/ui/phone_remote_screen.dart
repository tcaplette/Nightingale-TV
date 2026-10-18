import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_scope.dart';
import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';

/// Turn the phone remote on or off, and show where to find it.
class PhoneRemoteScreen extends StatelessWidget {
  const PhoneRemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final remote = HouseholdScope.of(context).remote!;
    final g = context.guide;
    return ListenableBuilder(
      listenable: remote,
      builder: (context, _) {
        final url = remote.url;
        return TvPage(
          title: 'Phone remote',
          hints: '◀▶ Move    OK Select    ESC Back',
          onBack: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(120, 48, 120, 48),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Use your phone as the remote: open a web page on it to change channels, '
                        'bring up the guide, or tap a channel to tune in. Nothing to install.',
                        style: g.body(30, color: g.textDim),
                      ),
                      const SizedBox(height: 36),
                      FocusTraversalGroup(
                        child: Wrap(
                          spacing: 12,
                          children: [
                            TvToggle(
                              label: 'On',
                              radio: true,
                              autofocus: true,
                              on: remote.enabled,
                              onPressed: () => remote.setEnabled(true),
                            ),
                            TvToggle(
                              label: 'Off',
                              radio: true,
                              on: !remote.enabled,
                              onPressed: () => remote.setEnabled(false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      if (remote.error != null)
                        Text(remote.error!, style: g.body(28, weight: FontWeight.w600, color: g.nowLine))
                      else if (url != null) ...[
                        Text('ON YOUR PHONE, OPEN', style: g.display(26, weight: FontWeight.w800, color: g.accent)),
                        const SizedBox(height: 8),
                        Text('$url', style: g.display(64, weight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        Text(
                          'or scan the code with the camera. The phone has to be on the same Wi-Fi as '
                          'this TV. Only devices on your home network can use it.',
                          style: g.body(26, color: g.textDim),
                        ),
                      ] else
                        Text('The remote is off.', style: g.body(28, color: g.textDim)),
                    ],
                  ),
                ),
                if (url != null) ...[
                  const SizedBox(width: 80),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(g.radius * 2)),
                    child: QrImageView(data: '$url', size: 420, backgroundColor: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
