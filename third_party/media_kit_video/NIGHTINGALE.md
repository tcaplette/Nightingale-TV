# media_kit_video 2.0.1, Linux video output rewritten

This is the upstream `media_kit_video` 2.0.1 package (MIT, see `LICENSE`).
`pubspec.yaml` swaps it in with `dependency_overrides`.

Only the Linux rendering layer changed. Every other platform, the Dart API
and the method channel are as published.

## Changed files

All of them are under `linux/`:

- `video_output.cc` and `include/media_kit_video/video_output.h`
- `texture_gl.cc` and `include/media_kit_video/texture_gl.h`
- `texture_sw.cc` and `include/media_kit_video/texture_sw.h`
- `include/media_kit_video/gl_context.h` (new)

## Why

**GPU rendering never started.** Flutter 3.47 renders with its own EGL
context (OpenGL ES) on its raster thread, on X11 and Wayland alike.
2.0.1 looks for that context with `eglGetCurrentContext()` on the main
thread, where it never is, so every machine falls back to software video.
The log shows:

```
media_kit: VideoOutput: EGL display or context is invalid.
media_kit: VideoOutput: S/W rendering.
```

**GPU frames weren't synchronized.** mpv's context and Flutter's were linked
through an EGLImage with only `glFlush()` between them. That doesn't order
two contexts' GPU work.

**The software fallback tore and blocked the main thread.**
- `copy_pixels` handed Flutter the shared pixel buffer without the lock,
  while the main thread drew the next frame into it.
- mpv's render call ran on the GTK main thread and blocked it until each
  frame was due.
- Frames over 1080p were scaled with integer division, which also shrank
  some smaller videos, such as 4:3 at 1440×1080.

## What it does now

**GPU path.**
- mpv's EGL context and render context are made when the video output is,
  on the EGL display Flutter renders on (`eglGetPlatformDisplayEXT` for GDK's
  display, which returns Flutter's display).
- They must exist before mpv starts video, because media_kit only shows the
  texture once video has a size. So mpv's context can't share Flutter's,
  which is only current on Flutter's raster thread. Making mpv's context in
  the populate callback deadlocks: no texture until there's video, no video
  until there's a context.
- Frames reach Flutter's context as EGLImages of mpv's textures.
- mpv draws into two textures in turn. EGL fence syncs, which work across
  contexts, order the two contexts' GPU work; without `EGL_KHR_fence_sync`
  it uses `glFinish()`.
- On the first frame the plugin checks that Flutter is on the same EGL
  display and can import EGLImages; if not, software rendering takes over.
- If mpv turned video off because it started before a render context
  existed, the plugin turns it back on.
- A mutex keeps teardown from freeing anything a frame is using. Teardown
  runs on the main thread, where GDK's GLX context is current. libglvnd
  allows EGL or GLX on a thread, not both, so the GLX context is released
  and restored around it.
- A GDK/GLX context for mpv does not work: it can't share textures with
  Flutter's EGL context, and libglvnd rejects it (`BadAccess`, GLX
  request 152/26).

**Software path.**
- It is used when Flutter's context isn't EGL or no EGL context can be made.
- mpv renders on its own thread and hands over complete frames.
- Flutter uploads a copy taken under the lock, and the reported size is the
  real size of that frame.

## Updating

If a newer upstream release fixes this, drop the override and this folder.
Until then, re-apply the files above on top of a new release, since nothing
outside `linux/` was touched.
