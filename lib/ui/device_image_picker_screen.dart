import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../platform/device_images.dart';
import '../theme/tv_theme.dart';
import 'widgets/tv_focus.dart';
import '../l10n/tr.dart';

/// The device's pictures in a grid, newest first, for a custom channel icon
/// where Android has no document picker (TVs). The D-pad, an air mouse and
/// touch all work. Pops the [DeviceImage] chosen, or null.
class DeviceImagePickerScreen extends StatefulWidget {
  const DeviceImagePickerScreen({super.key, this.load = DeviceImages.list, this.thumbnail = DeviceImages.thumbnail});

  /// For tests.
  final Future<List<DeviceImage>> Function() load;
  final Future<Uint8List?> Function(DeviceImage image) thumbnail;

  @override
  State<DeviceImagePickerScreen> createState() => _DeviceImagePickerScreenState();
}

class _DeviceImagePickerScreenState extends State<DeviceImagePickerScreen> {
  late final Future<List<DeviceImage>> _images = widget.load();
  final _first = FocusNode(debugLabel: 'first picture');
  final _thumbnails = <String, Future<Uint8List?>>{};

  @override
  void initState() {
    super.initState();
    _images.then((images) {
      if (images.isNotEmpty) _focusFirst();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  /// The page holds focus while the list loads, so autofocus on the grid
  /// built later never happens: focus the first picture once it's built.
  void _focusFirst([int framesLeft = 30]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || framesLeft == 0) return;
      if (_first.context == null) return _focusFirst(framesLeft - 1);
      _first.requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.guide;
    return TvPage(
      title: tr.chooseAPicture,
      hints: tr.moveOkChooseEsc,
      onBack: () => Navigator.of(context).pop(),
      child: FutureBuilder<List<DeviceImage>>(
        future: _images,
        builder: (context, snapshot) {
          final error = snapshot.error;
          final images = snapshot.data;
          final String? message = switch ((error, images)) {
            (DeviceImagesDenied(), _) =>
              tr.nightingaleTvIsnt,
            (Object(), _) => tr.couldntReadThePictures,
            (_, null) => tr.lookingForPictures,
            (_, []) => tr.noPicturesOn,
            _ => null,
          };
          if (message != null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(80, 48, 80, 32),
              child: Text(message, style: g.body(28, color: g.textDim)),
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(80, 24, 80, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.picturesOnThis,
                    style: g.body(24, color: g.textDim)),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 200 / 240,
                    ),
                    itemCount: images!.length,
                    itemBuilder: (context, i) => _tile(g, images[i], i == 0 ? _first : null),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(GuideTheme g, DeviceImage image, FocusNode? node) {
    final thumbnail = _thumbnails.putIfAbsent(image.uri, () => widget.thumbnail(image));
    return TvFocusable(
      focusNode: node,
      onPressed: () => Navigator.of(context).pop(image),
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: focused ? g.cellBorder : g.cell,
          borderRadius: BorderRadius.circular(g.radius * 2),
          border: Border.all(color: focused ? g.focus : Colors.transparent, width: focused ? 5 : 3),
        ),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<Uint8List?>(
                future: thumbnail,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  return Center(
                    child: bytes == null
                        ? Icon(Icons.image_outlined, size: 64, color: g.textDim)
                        : Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(image.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(20, color: focused ? g.text : g.textDim)),
            if (image.folder != null)
              Text(image.folder!, maxLines: 1, overflow: TextOverflow.ellipsis, style: g.body(16, color: g.textDim)),
          ],
        ),
      ),
    );
  }
}
