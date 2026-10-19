// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_sw.h"

#include <string.h>

// The rendering thread hands over complete frames in |texture_sw_publish|.
// Flutter uploads a copy taken under the lock, so it never reads a frame
// while the next one is drawn into it.
struct _TextureSW {
  FlPixelBufferTexture parent_instance;
  GMutex mutex;
  guint8* front; /* The last complete frame. */
  guint32 front_width;
  guint32 front_height;
  guint8* copy; /* What Flutter uploads; raster thread only. */
  guint32 current_width;
  guint32 current_height;
  VideoOutput* video_output; /* NULL once released. */
};

G_DEFINE_TYPE(TextureSW, texture_sw, fl_pixel_buffer_texture_get_type())

static void texture_sw_init(TextureSW* self) {
  g_mutex_init(&self->mutex);
  self->front = NULL;
  self->front_width = 0;
  self->front_height = 0;
  self->copy = g_new0(guint8, SW_RENDERING_PIXEL_BUFFER_SIZE);
  self->current_width = 1;
  self->current_height = 1;
  self->video_output = NULL;
}

static void texture_sw_finalize(GObject* object) {
  TextureSW* self = TEXTURE_SW(object);
  g_free(self->front);
  g_free(self->copy);
  g_mutex_clear(&self->mutex);
  G_OBJECT_CLASS(texture_sw_parent_class)->finalize(object);
}

static void texture_sw_class_init(TextureSWClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = texture_sw_copy_pixels;
  G_OBJECT_CLASS(klass)->finalize = texture_sw_finalize;
}

TextureSW* texture_sw_new(VideoOutput* video_output) {
  TextureSW* self = TEXTURE_SW(g_object_new(texture_sw_get_type(), NULL));
  self->video_output = video_output;
  return self;
}

guint8* texture_sw_publish(TextureSW* self,
                           guint8* frame,
                           guint32 width,
                           guint32 height) {
  g_mutex_lock(&self->mutex);
  guint8* previous = self->front;
  self->front = frame;
  self->front_width = width;
  self->front_height = height;
  g_mutex_unlock(&self->mutex);
  return previous != NULL ? previous
                          : g_new0(guint8, SW_RENDERING_PIXEL_BUFFER_SIZE);
}

void texture_sw_release(TextureSW* self) {
  g_mutex_lock(&self->mutex);
  self->video_output = NULL;
  g_mutex_unlock(&self->mutex);
}

gboolean texture_sw_copy_pixels(FlPixelBufferTexture* texture,
                                const guint8** buffer,
                                guint32* width,
                                guint32* height,
                                GError** error) {
  TextureSW* self = TEXTURE_SW(texture);
  g_mutex_lock(&self->mutex);
  guint32 frame_width = self->front_width;
  guint32 frame_height = self->front_height;
  if (self->front != NULL && frame_width > 0 && frame_height > 0) {
    memcpy(self->copy, self->front, (gsize)frame_width * frame_height * 4);
  } else {
    // No frame yet: one transparent pixel.
    frame_width = 1;
    frame_height = 1;
    memset(self->copy, 0, 4);
  }
  if (self->video_output != NULL && (frame_width != self->current_width ||
                                     frame_height != self->current_height)) {
    self->current_width = frame_width;
    self->current_height = frame_height;
    // Notify Flutter about the change in texture's dimensions.
    video_output_notify_texture_update(self->video_output);
  }
  g_mutex_unlock(&self->mutex);
  *buffer = self->copy;
  *width = frame_width;
  *height = frame_height;
  return TRUE;
}
