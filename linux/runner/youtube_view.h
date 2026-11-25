#ifndef RUNNER_YOUTUBE_VIEW_H_
#define RUNNER_YOUTUBE_VIEW_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

// YouTube's embedded player on Linux (youtube-playback D8): one WebKitGTK
// view inside the app's window, laid over the Flutter view in [overlay] at
// the frame Dart gives. It never takes key focus. Pointer events reach it.
// Driven over the `ntv/youtube_view` method channel.
void youtube_view_register(GtkOverlay* overlay, FlView* view);

#endif  // RUNNER_YOUTUBE_VIEW_H_
