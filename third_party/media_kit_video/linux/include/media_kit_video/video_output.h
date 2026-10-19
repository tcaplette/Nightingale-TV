// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef VIDEO_OUTPUT_H_
#define VIDEO_OUTPUT_H_

#include <flutter_linux/flutter_linux.h>

#include "mpv/client.h"
#include "mpv/render.h"
#include "mpv/render_gl.h"

typedef struct _VideoOutputConfiguration {
  gint64 width;
  gint64 height;
  bool enable_hardware_acceleration;

  _VideoOutputConfiguration(gint64 width = NULL,
                            gint64 height = NULL,
                            bool enable_hardware_acceleration = true)
      : width(width),
        height(height),
        enable_hardware_acceleration(enable_hardware_acceleration) {}
} VideoOutputConfiguration;

// Callback invoked when the texture ID updates i.e. video dimensions changes.
typedef void (*TextureUpdateCallback)(gint64 id,
                                      gint64 width,
                                      gint64 height,
                                      gpointer context);

#define VIDEO_OUTPUT_TYPE (video_output_get_type())

G_DECLARE_FINAL_TYPE(VideoOutput,
                     video_output,
                     VIDEO_OUTPUT,
                     VIDEO_OUTPUT,
                     GObject)

#define VIDEO_OUTPUT(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), video_output_get_type(), VideoOutput))

/**
 * @brief Creates a new |VideoOutput| instance for given |handle|.
 *
 * H/W rendering uses an EGL context on Flutter's EGL display, whose frames
 * reach Flutter as EGLImages. If none can be made, S/W rendering.
 *
 * @param texture_registrar |FlTextureRegistrar| reference.
 * @param view The |FlView| Flutter draws in.
 * @param handle |mpv_handle| reference casted to gint64.
 * @param configuration Preferred size (`NULL` width & height for the video's
 * resolution) and whether to enable hardware acceleration.
 * @return VideoOutput*
 */
VideoOutput* video_output_new(FlTextureRegistrar* texture_registrar,
                              FlView* view,
                              gint64 handle,
                              VideoOutputConfiguration configuration);

/**
 * @brief Sets the callback invoked when the texture ID updates i.e. video
 * dimensions changes.
 *
 * @param self |VideoOutput| reference.
 * @param texture_update_callback Callback.
 * @param texture_update_callback_context Callback context.
 */
void video_output_set_texture_update_callback(
    VideoOutput* self,
    TextureUpdateCallback texture_update_callback,
    gpointer texture_update_callback_context);

/**
 * @brief Sets the required video output size. This forces |VideoOutput| to
 * resize the internal OpenGL surface / texture.
 *
 * @param texture_registrar |FlTextureRegistrar| reference.
 * @param width Preferred width of the video. Pass `NULL` for using texture
 * dimensions based on video's resolution.
 * @param height Preferred height of the video. Pass `NULL` for using texture
 * dimensions based on video's resolution.
 */
void video_output_set_size(VideoOutput* self, gint64 width, gint64 height);

gint64 video_output_get_width(VideoOutput* self);

gint64 video_output_get_height(VideoOutput* self);

mpv_handle* video_output_get_handle(VideoOutput* self);

/**
 * @brief Replaces H/W rendering with S/W rendering, on the main thread, when
 * no OpenGL context could be made. Safe to call from any thread.
 */
void video_output_fall_back_to_sw(VideoOutput* self);

/**
 * @brief Turns video back on if mpv turned it off because it started before a
 * render context existed.
 */
void video_output_restart_video(VideoOutput* self);

gint64 video_output_get_texture_id(VideoOutput* self);

void video_output_notify_texture_update(VideoOutput* self);

#endif  // VIDEO_OUTPUT_H_
