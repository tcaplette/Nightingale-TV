// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/video_output.h"
#include "include/media_kit_video/texture_gl.h"
#include "include/media_kit_video/texture_sw.h"

#include <string.h>

static void video_output_get_size(VideoOutput* self,
                                  gint64* width,
                                  gint64* height);

struct _VideoOutput {
  GObject parent_instance;
  TextureGL* texture_gl; /* H/W; owns its render context. */
  TextureSW* texture_sw; /* S/W. */
  mpv_render_context* sw_render_context;
  GThread* sw_thread; /* S/W: renders frames off the main thread. */
  GMutex sw_mutex;
  GCond sw_cond;
  gboolean sw_pending;
  gboolean sw_quit;
  mpv_handle* handle;
  gint64 width;
  gint64 height;
  VideoOutputConfiguration configuration;
  TextureUpdateCallback texture_update_callback;
  gpointer texture_update_callback_context;
  FlTextureRegistrar* texture_registrar;
  gboolean destroyed;
};

G_DEFINE_TYPE(VideoOutput, video_output, G_TYPE_OBJECT)

static void video_output_dispose(GObject* object) {
  VideoOutput* self = VIDEO_OUTPUT(object);
  self->destroyed = TRUE;
  // H/W
  if (self->texture_gl != NULL) {
    texture_gl_release(self->texture_gl);
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_gl));
    g_clear_object(&self->texture_gl);
  }
  // S/W
  if (self->texture_sw != NULL) {
    if (self->sw_render_context != NULL) {
      mpv_render_context_set_update_callback(self->sw_render_context, NULL,
                                             NULL);
    }
    if (self->sw_thread != NULL) {
      g_mutex_lock(&self->sw_mutex);
      self->sw_quit = TRUE;
      g_cond_signal(&self->sw_cond);
      g_mutex_unlock(&self->sw_mutex);
      g_thread_join(self->sw_thread);
      self->sw_thread = NULL;
    }
    texture_sw_release(self->texture_sw);
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_sw));
    if (self->sw_render_context != NULL) {
      mpv_render_context_free(self->sw_render_context);
      self->sw_render_context = NULL;
    }
    g_clear_object(&self->texture_sw);
  }
  G_OBJECT_CLASS(video_output_parent_class)->dispose(object);
}

static void video_output_finalize(GObject* object) {
  VideoOutput* self = VIDEO_OUTPUT(object);
  g_mutex_clear(&self->sw_mutex);
  g_cond_clear(&self->sw_cond);
  G_OBJECT_CLASS(video_output_parent_class)->finalize(object);
}

static void video_output_class_init(VideoOutputClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = video_output_dispose;
  G_OBJECT_CLASS(klass)->finalize = video_output_finalize;
}

static void video_output_init(VideoOutput* self) {
  self->texture_gl = NULL;
  self->texture_sw = NULL;
  self->sw_render_context = NULL;
  self->sw_thread = NULL;
  g_mutex_init(&self->sw_mutex);
  g_cond_init(&self->sw_cond);
  self->sw_pending = FALSE;
  self->sw_quit = FALSE;
  self->handle = NULL;
  self->width = 0;
  self->height = 0;
  self->configuration = VideoOutputConfiguration{};
  self->texture_update_callback = NULL;
  self->texture_update_callback_context = NULL;
  self->texture_registrar = NULL;
  self->destroyed = FALSE;
}

// H/W: see |TextureGL|.
static gboolean video_output_init_gl(VideoOutput* self) {
  TextureGL* texture_gl = texture_gl_new(self, self->texture_registrar);
  if (texture_gl == NULL) {
    return FALSE;
  }
  if (!fl_texture_registrar_register_texture(self->texture_registrar,
                                             FL_TEXTURE(texture_gl))) {
    g_printerr("media_kit: VideoOutput: Failed to register texture.\n");
    texture_gl_release(texture_gl);
    g_object_unref(texture_gl);
    return FALSE;
  }
  self->texture_gl = texture_gl;
  return TRUE;
}

#ifdef MPV_RENDER_API_TYPE_SW
// S/W: mpv draws into memory on its own thread, since a render call blocks
// until its frame is due. Each complete frame is handed to |TextureSW|.
static gpointer video_output_sw_thread(gpointer data) {
  VideoOutput* self = (VideoOutput*)data;
  guint8* frame = g_new0(guint8, SW_RENDERING_PIXEL_BUFFER_SIZE);
  while (TRUE) {
    g_mutex_lock(&self->sw_mutex);
    while (!self->sw_pending && !self->sw_quit) {
      g_cond_wait(&self->sw_cond, &self->sw_mutex);
    }
    gboolean quit = self->sw_quit;
    self->sw_pending = FALSE;
    g_mutex_unlock(&self->sw_mutex);
    if (quit) {
      break;
    }
    // One read, so width and height belong to the same video.
    gint64 width = 0, height = 0;
    video_output_get_size(self, &width, &height);
    if (width <= 0 || height <= 0) {
      continue;
    }
    gint32 size[]{(gint32)width, (gint32)height};
    gint32 pitch = 4 * (gint32)width;
    mpv_render_param params[]{
        {MPV_RENDER_PARAM_SW_SIZE, size},
        {MPV_RENDER_PARAM_SW_FORMAT, (void*)"rgb0"},
        {MPV_RENDER_PARAM_SW_STRIDE, &pitch},
        {MPV_RENDER_PARAM_SW_POINTER, frame},
        {MPV_RENDER_PARAM_INVALID, (void*)0},
    };
    mpv_render_context_render(self->sw_render_context, params);
    frame = texture_sw_publish(self->texture_sw, frame, (guint32)width,
                               (guint32)height);
    fl_texture_registrar_mark_texture_frame_available(
        self->texture_registrar, FL_TEXTURE(self->texture_sw));
  }
  g_free(frame);
  return NULL;
}

static void video_output_init_sw(VideoOutput* self) {
  g_printerr("media_kit: VideoOutput: S/W rendering.\n");
  self->texture_sw = texture_sw_new(self);
  if (!fl_texture_registrar_register_texture(self->texture_registrar,
                                             FL_TEXTURE(self->texture_sw))) {
    return;
  }
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_SW},
      {MPV_RENDER_PARAM_INVALID, (void*)0},
  };
  if (mpv_render_context_create(&self->sw_render_context, self->handle,
                                params) != 0) {
    self->sw_render_context = NULL;
    return;
  }
  self->sw_thread =
      g_thread_new("media_kit S/W rendering", video_output_sw_thread, self);
  mpv_render_context_set_update_callback(
      self->sw_render_context,
      [](void* data) {
        VideoOutput* self = (VideoOutput*)data;
        g_mutex_lock(&self->sw_mutex);
        self->sw_pending = TRUE;
        g_cond_signal(&self->sw_cond);
        g_mutex_unlock(&self->sw_mutex);
      },
      self);
}
#endif

VideoOutput* video_output_new(FlTextureRegistrar* texture_registrar,
                              FlView* view,
                              gint64 handle,
                              VideoOutputConfiguration configuration) {
  VideoOutput* self = VIDEO_OUTPUT(g_object_new(video_output_get_type(), NULL));
  self->texture_registrar = texture_registrar;
  self->handle = (mpv_handle*)handle;
  self->width = configuration.width;
  self->height = configuration.height;
  self->configuration = configuration;
#ifndef MPV_RENDER_API_TYPE_SW
  // MPV_RENDER_API_TYPE_SW must be available for S/W rendering.
  if (!self->configuration.enable_hardware_acceleration) {
    g_printerr("media_kit: VideoOutput: S/W rendering is not supported.\n");
  }
  self->configuration.enable_hardware_acceleration = TRUE;
#endif
  mpv_set_option_string(self->handle, "video-sync", "audio");
  // Causes frame drops with `pulse` audio output. (SlotSun/dart_simple_live#42)
  // mpv_set_option_string(self->handle, "video-timing-offset", "0");
  gboolean hardware_acceleration_supported = FALSE;
  if (self->configuration.enable_hardware_acceleration) {
    hardware_acceleration_supported = video_output_init_gl(self);
  }
#ifdef MPV_RENDER_API_TYPE_SW
  if (!hardware_acceleration_supported) {
    // H/W rendering failed. Fallback to S/W rendering.
    video_output_init_sw(self);
  }
#endif
  return self;
}

void video_output_fall_back_to_sw(VideoOutput* self) {
  // On the main thread: |TextureGL| calls this while populating.
  g_idle_add(
      [](gpointer data) -> gboolean {
        VideoOutput* self = VIDEO_OUTPUT(data);
        if (!self->destroyed && self->texture_gl != NULL) {
          texture_gl_release(self->texture_gl);
          fl_texture_registrar_unregister_texture(self->texture_registrar,
                                                  FL_TEXTURE(self->texture_gl));
          g_clear_object(&self->texture_gl);
#ifdef MPV_RENDER_API_TYPE_SW
          video_output_init_sw(self);
          video_output_restart_video(self);
#endif
          // A new texture: Flutter mounts it at 1x1 until frames arrive.
          if (self->texture_sw != NULL && self->texture_update_callback != NULL) {
            self->texture_update_callback(video_output_get_texture_id(self), 1,
                                          1,
                                          self->texture_update_callback_context);
          }
        }
        g_object_unref(self);
        return G_SOURCE_REMOVE;
      },
      g_object_ref(self));
}

void video_output_restart_video(VideoOutput* self) {
  // mpv starts video as soon as a file has it. Before a render context exists
  // that fails ("No render context set") and mpv turns the track off: turn it
  // back on, unless video was turned off on purpose.
  char* vid = mpv_get_property_string(self->handle, "options/vid");
  gboolean wanted = g_strcmp0(vid, "no") != 0;
  mpv_free(vid);
  if (!wanted) {
    return;
  }
  char* vo = mpv_get_property_string(self->handle, "current-vo");
  if (vo != NULL) {
    // Video is running.
    mpv_free(vo);
    return;
  }
  mpv_node tracks;
  if (mpv_get_property(self->handle, "track-list", MPV_FORMAT_NODE, &tracks) <
      0) {
    return;
  }
  int64_t id = -1;
  if (tracks.format == MPV_FORMAT_NODE_ARRAY) {
    for (int32_t i = 0; i < tracks.u.list->num && id < 0; i++) {
      mpv_node* track = &tracks.u.list->values[i];
      if (track->format != MPV_FORMAT_NODE_MAP) {
        continue;
      }
      const char* type = NULL;
      int64_t track_id = -1;
      int selected = 0, albumart = 0;
      for (int32_t j = 0; j < track->u.list->num; j++) {
        const char* key = track->u.list->keys[j];
        mpv_node* value = &track->u.list->values[j];
        if (strcmp(key, "type") == 0 && value->format == MPV_FORMAT_STRING) {
          type = value->u.string;
        } else if (strcmp(key, "id") == 0 &&
                   value->format == MPV_FORMAT_INT64) {
          track_id = value->u.int64;
        } else if (strcmp(key, "selected") == 0 &&
                   value->format == MPV_FORMAT_FLAG) {
          selected = value->u.flag;
        } else if (strcmp(key, "albumart") == 0 &&
                   value->format == MPV_FORMAT_FLAG) {
          albumart = value->u.flag;
        }
      }
      // A selected track is still starting; it finds the render context.
      if (g_strcmp0(type, "video") == 0 && !albumart && !selected) {
        id = track_id;
      }
    }
  }
  mpv_free_node_contents(&tracks);
  if (id >= 0) {
    mpv_set_property_async(self->handle, 0, "vid", MPV_FORMAT_INT64, &id);
  }
}

void video_output_set_texture_update_callback(
    VideoOutput* self,
    TextureUpdateCallback texture_update_callback,
    gpointer texture_update_callback_context) {
  self->texture_update_callback = texture_update_callback;
  self->texture_update_callback_context = texture_update_callback_context;
  // Notify initial dimensions as (1, 1) if |width| & |height| are 0 i.e.
  // texture & video frame size is based on playing file's resolution. This
  // will make sure that `Texture` widget on Flutter's widget tree is actually
  // mounted & |fl_texture_registrar_mark_texture_frame_available| actually
  // invokes the |TextureGL| or |TextureSW| callbacks. Otherwise it will be a
  // never ending deadlock where no video frames are ever rendered.
  gint64 texture_id = video_output_get_texture_id(self);
  if (self->width == 0 || self->height == 0) {
    self->texture_update_callback(texture_id, 1, 1,
                                  self->texture_update_callback_context);
  } else {
    self->texture_update_callback(texture_id, self->width, self->height,
                                  self->texture_update_callback_context);
  }
}

void video_output_set_size(VideoOutput* self, gint64 width, gint64 height) {
  // Ideally, a mutex should be used here & |video_output_get_width| +
  // |video_output_get_height|. However, that is throwing everything into a
  // deadlock. Flutter itself seems to have some synchronization mechanism in
  // rendering & platform channels AFAIK.

  // H/W
  if (self->texture_gl) {
    self->width = width;
    self->height = height;
  }
  // S/W
  if (self->texture_sw) {
    self->width = CLAMP(width, 0, SW_RENDERING_MAX_WIDTH);
    self->height = CLAMP(height, 0, SW_RENDERING_MAX_HEIGHT);
  }
}

// The size frames are rendered at: the preferred size if one is set, else the
// video's display size (rotation applied). S/W rendering scales it down to fit
// within its limit, keeping the aspect ratio.
static void video_output_get_size(VideoOutput* self,
                                  gint64* width,
                                  gint64* height) {
  // Fixed size.
  if (self->width) {
    *width = self->width;
    *height = self->height;
    return;
  }

  // Video resolution dependent size.
  mpv_node params;
  mpv_get_property(self->handle, "video-out-params", MPV_FORMAT_NODE, &params);

  int64_t dw = 0, dh = 0, rotate = 0;
  if (params.format == MPV_FORMAT_NODE_MAP) {
    for (int32_t i = 0; i < params.u.list->num; i++) {
      char* key = params.u.list->keys[i];
      auto value = params.u.list->values[i];
      if (value.format == MPV_FORMAT_INT64) {
        if (strcmp(key, "dw") == 0) {
          dw = value.u.int64;
        }
        if (strcmp(key, "dh") == 0) {
          dh = value.u.int64;
        }
        if (strcmp(key, "rotate") == 0) {
          rotate = value.u.int64;
        }
      }
    }
    mpv_free_node_contents(&params);
  }

  *width = rotate == 0 || rotate == 180 ? dw : dh;
  *height = rotate == 0 || rotate == 180 ? dh : dw;

  if (self->texture_sw != NULL && *width > 0 && *height > 0 &&
      (*width > SW_RENDERING_MAX_WIDTH || *height > SW_RENDERING_MAX_HEIGHT)) {
    gdouble scale = MIN((gdouble)SW_RENDERING_MAX_WIDTH / *width,
                        (gdouble)SW_RENDERING_MAX_HEIGHT / *height);
    *width = MAX(1, (gint64)(*width * scale));
    *height = MAX(1, (gint64)(*height * scale));
  }
}

gint64 video_output_get_width(VideoOutput* self) {
  gint64 width = 0, height = 0;
  video_output_get_size(self, &width, &height);
  return width;
}

gint64 video_output_get_height(VideoOutput* self) {
  gint64 width = 0, height = 0;
  video_output_get_size(self, &width, &height);
  return height;
}

mpv_handle* video_output_get_handle(VideoOutput* self) {
  return self->handle;
}

gint64 video_output_get_texture_id(VideoOutput* self) {
  // H/W
  if (self->texture_gl) {
    return (gint64)self->texture_gl;
  }
  // S/W
  if (self->texture_sw) {
    return (gint64)self->texture_sw;
  }
  g_assert_not_reached();
  return -1;
}

void video_output_notify_texture_update(VideoOutput* self) {
  gint64 id = video_output_get_texture_id(self);
  gint64 width = video_output_get_width(self);
  gint64 height = video_output_get_height(self);
  gpointer context = self->texture_update_callback_context;
  if (self->texture_update_callback != NULL) {
    self->texture_update_callback(id, width, height, context);
  }
}
