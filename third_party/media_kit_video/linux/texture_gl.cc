// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_gl.h"

#include <string.h>

#include "include/media_kit_video/gl_context.h"

#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif

// mpv renders with its own EGL context on the EGL display Flutter renders on.
// It is made when the video output is (mpv starts video as soon as a file
// has it, and media_kit only shows the texture once video has a size), so it
// can't share Flutter's context, which is only current on Flutter's raster
// thread. Frames reach Flutter's context as EGLImages of mpv's textures, and
// EGL fence syncs (which work across contexts) order the two contexts' GPU
// work. Two textures take turns, so mpv never draws into the one Flutter's
// last frame may still be reading.
struct _TextureGL {
  FlTextureGL parent_instance;
  // Held while rendering and while releasing, so a release never frees what a
  // frame on Flutter's raster thread is using.
  GMutex mutex;
  VideoOutput* video_output; /* NULL once released. */
  FlTextureRegistrar* texture_registrar;
  EGLDisplay display;
  EGLContext context; /* mpv's. */
  EGLSurface surface; /* EGL_NO_SURFACE when surfaceless. */
  mpv_render_context* render_context;
  gboolean fences;      /* EGL_KHR_fence_sync; else glFinish(). */
  gboolean wait_sync;   /* EGL_KHR_wait_sync: waits on the GPU. */
  gboolean checked;     /* Flutter's side checked, on the first populate. */
  gboolean failed;      /* S/W rendering takes over. */
  guint32 textures[2];  /* mpv's context. */
  guint32 framebuffers[2];
  EGLImageKHR images[2];
  guint32 flutter_textures[2]; /* Flutter's context, of |images|. */
  guint32 front;               /* Index of the texture Flutter shows. */
  guint32 width;
  guint32 height;
  guint32 placeholder; /* Flutter's context: 1x1, before the first frame. */
};

G_DEFINE_TYPE(TextureGL, texture_gl, fl_texture_gl_get_type())

static void texture_gl_init(TextureGL* self) {
  g_mutex_init(&self->mutex);
  self->video_output = NULL;
  self->texture_registrar = NULL;
  self->display = EGL_NO_DISPLAY;
  self->context = EGL_NO_CONTEXT;
  self->surface = EGL_NO_SURFACE;
  self->render_context = NULL;
  self->fences = FALSE;
  self->wait_sync = FALSE;
  self->checked = FALSE;
  self->failed = FALSE;
  for (gint i = 0; i < 2; i++) {
    self->textures[i] = 0;
    self->framebuffers[i] = 0;
    self->images[i] = EGL_NO_IMAGE_KHR;
    self->flutter_textures[i] = 0;
  }
  self->front = 0;
  self->width = 0;
  self->height = 0;
  self->placeholder = 0;
}

static void texture_gl_finalize(GObject* object) {
  g_mutex_clear(&TEXTURE_GL(object)->mutex);
  G_OBJECT_CLASS(texture_gl_parent_class)->finalize(object);
}

static void texture_gl_class_init(TextureGLClass* klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = texture_gl_populate_texture;
  G_OBJECT_CLASS(klass)->finalize = texture_gl_finalize;
}

// The EGL display Flutter renders on: Flutter gets it with
// eglGetPlatformDisplayEXT for GDK's display, and EGL returns the same
// display for the same arguments.
static EGLDisplay texture_gl_get_display(mpv_render_param* native_display) {
  GdkDisplay* display = gdk_display_get_default();
#ifdef GDK_WINDOWING_WAYLAND
  if (GDK_IS_WAYLAND_DISPLAY(display)) {
    struct wl_display* wl_display = gdk_wayland_display_get_wl_display(display);
    *native_display = mpv_render_param{MPV_RENDER_PARAM_WL_DISPLAY, wl_display};
    return eglGetPlatformDisplayEXT(EGL_PLATFORM_WAYLAND_EXT, wl_display, NULL);
  }
#endif
#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_DISPLAY(display)) {
    Display* x_display = gdk_x11_display_get_xdisplay(display);
    *native_display = mpv_render_param{MPV_RENDER_PARAM_X11_DISPLAY, x_display};
    return eglGetPlatformDisplayEXT(EGL_PLATFORM_X11_EXT, x_display, NULL);
  }
#endif
  return EGL_NO_DISPLAY;
}

static void texture_gl_destroy_context(TextureGL* self) {
  if (self->surface != EGL_NO_SURFACE) {
    eglDestroySurface(self->display, self->surface);
  }
  if (self->context != EGL_NO_CONTEXT) {
    eglDestroyContext(self->display, self->context);
  }
  self->surface = EGL_NO_SURFACE;
  self->context = EGL_NO_CONTEXT;
}

TextureGL* texture_gl_new(VideoOutput* video_output,
                          FlTextureRegistrar* texture_registrar) {
  mpv_render_param native_display{MPV_RENDER_PARAM_INVALID, NULL};
  EGLDisplay display = texture_gl_get_display(&native_display);
  if (display == EGL_NO_DISPLAY || !eglInitialize(display, NULL, NULL)) {
    g_printerr("media_kit: TextureGL: No EGL display.\n");
    return NULL;
  }
  // Handing frames to Flutter's context takes EGLImages of GL textures.
  if (!epoxy_has_egl_extension(display, "EGL_KHR_image_base") ||
      !epoxy_has_egl_extension(display, "EGL_KHR_gl_texture_2D_image")) {
    g_printerr("media_kit: TextureGL: EGL can't share GL textures.\n");
    return NULL;
  }
  // OpenGL ES 3 where available (mpv renders 10-bit video better), else 2.
  EGLint es3_config[] = {
      EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE,
      EGL_OPENGL_ES3_BIT_KHR, EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8,
      EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE,
  };
  EGLint es2_config[] = {
      EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE,
      EGL_OPENGL_ES2_BIT, EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8,
      EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE,
  };
  EGLint es3_context[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
  EGLint es2_context[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLConfig config = NULL;
  EGLint count = 0;
  EGLContext context = EGL_NO_CONTEXT;
  EGLenum previous_api = eglQueryAPI();
  eglBindAPI(EGL_OPENGL_ES_API);
  if (eglChooseConfig(display, es3_config, &config, 1, &count) && count > 0) {
    context = eglCreateContext(display, config, EGL_NO_CONTEXT, es3_context);
  }
  if (context == EGL_NO_CONTEXT &&
      eglChooseConfig(display, es2_config, &config, 1, &count) && count > 0) {
    context = eglCreateContext(display, config, EGL_NO_CONTEXT, es2_context);
  }
  eglBindAPI(previous_api);
  if (context == EGL_NO_CONTEXT) {
    g_printerr("media_kit: TextureGL: Failed to create an EGL context (0x%x).\n",
               eglGetError());
    return NULL;
  }

  TextureGL* self = TEXTURE_GL(g_object_new(texture_gl_get_type(), NULL));
  self->video_output = video_output;
  self->texture_registrar = texture_registrar;
  self->display = display;
  self->context = context;
  self->fences = epoxy_has_egl_extension(display, "EGL_KHR_fence_sync");
  self->wait_sync =
      self->fences && epoxy_has_egl_extension(display, "EGL_KHR_wait_sync");
  // Surfaceless where supported, else a 1x1 pbuffer.
  if (!epoxy_has_egl_extension(display, "EGL_KHR_surfaceless_context")) {
    EGLint size[] = {EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE};
    self->surface = eglCreatePbufferSurface(display, config, size);
    if (self->surface == EGL_NO_SURFACE) {
      g_printerr("media_kit: TextureGL: Failed to create a pbuffer (0x%x).\n",
                 eglGetError());
      texture_gl_destroy_context(self);
      g_object_unref(self);
      return NULL;
    }
  }

  // Usually on the main thread, where GDK's context is current.
  GLCurrent previous;
  mpv_render_context* render_context = NULL;
  if (gl_switch_to(&previous, display, self->surface, context,
                   EGL_OPENGL_ES_API)) {
    mpv_opengl_init_params gl_init_params{
        [](void*, const char* name) -> void* {
          return (void*)eglGetProcAddress(name);
        },
        NULL,
    };
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_OPENGL},
        {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, (void*)&gl_init_params},
        native_display,
        {MPV_RENDER_PARAM_INVALID, (void*)0},
    };
    if (mpv_render_context_create(&render_context,
                                  video_output_get_handle(video_output),
                                  params) != 0) {
      render_context = NULL;
    }
  }
  gl_switch_back(&previous, display);
  if (render_context == NULL) {
    g_printerr("media_kit: TextureGL: Failed to create mpv_render_context.\n");
    texture_gl_destroy_context(self);
    g_object_unref(self);
    return NULL;
  }
  self->render_context = render_context;
  mpv_render_context_set_update_callback(
      render_context,
      [](void* data) {
        TextureGL* self = (TextureGL*)data;
        fl_texture_registrar_mark_texture_frame_available(
            self->texture_registrar, FL_TEXTURE(self));
      },
      self);
  g_printerr("media_kit: TextureGL: H/W rendering (EGL, frames shared with "
             "Flutter as EGLImages).\n");
  return self;
}

// Inserts a fence into the current context's commands; EGL_NO_SYNC_KHR
// without fence syncs.
static EGLSyncKHR texture_gl_fence(TextureGL* self) {
  if (!self->fences) {
    return EGL_NO_SYNC_KHR;
  }
  EGLSyncKHR sync = eglCreateSyncKHR(self->display, EGL_SYNC_FENCE_KHR, NULL);
  glFlush();
  return sync;
}

// Makes the current context's later commands wait for |sync|.
static void texture_gl_wait(TextureGL* self, EGLSyncKHR sync) {
  if (sync == EGL_NO_SYNC_KHR) {
    return;
  }
  if (self->wait_sync) {
    eglWaitSyncKHR(self->display, sync, 0);
  } else {
    eglClientWaitSyncKHR(self->display, sync, EGL_SYNC_FLUSH_COMMANDS_BIT_KHR,
                         EGL_FOREVER_KHR);
  }
  eglDestroySyncKHR(self->display, sync);
}

// With mpv's context current.
static void texture_gl_delete_targets(TextureGL* self) {
  glDeleteFramebuffers(2, self->framebuffers);
  glDeleteTextures(2, self->textures);
  for (gint i = 0; i < 2; i++) {
    self->framebuffers[i] = 0;
    self->textures[i] = 0;
  }
}

// With mpv's context current: two |width| x |height| textures, each the color
// attachment of its own framebuffer, and EGLImages of them. The old images
// stay in |old_images| until Flutter's textures of them are gone.
static void texture_gl_create_targets(TextureGL* self,
                                      guint32 width,
                                      guint32 height,
                                      EGLImageKHR old_images[2]) {
  texture_gl_delete_targets(self);
  glGenTextures(2, self->textures);
  glGenFramebuffers(2, self->framebuffers);
  for (gint i = 0; i < 2; i++) {
    glBindTexture(GL_TEXTURE_2D, self->textures[i]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA,
                 GL_UNSIGNED_BYTE, NULL);
    glBindFramebuffer(GL_FRAMEBUFFER, self->framebuffers[i]);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                           self->textures[i], 0);
    old_images[i] = self->images[i];
    EGLint attributes[] = {EGL_GL_TEXTURE_LEVEL_KHR, 0, EGL_NONE};
    self->images[i] =
        eglCreateImageKHR(self->display, self->context, EGL_GL_TEXTURE_2D_KHR,
                          (EGLClientBuffer)(guintptr)self->textures[i],
                          attributes);
  }
  glBindTexture(GL_TEXTURE_2D, 0);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  self->width = width;
  self->height = height;
}

// With Flutter's context current: Flutter's textures of the new images. The
// texture binding is put back, so Flutter's GL state is as it was.
static void texture_gl_import_targets(TextureGL* self,
                                      EGLImageKHR old_images[2]) {
  GLint binding = 0;
  glGetIntegerv(GL_TEXTURE_BINDING_2D, &binding);
  glDeleteTextures(2, self->flutter_textures);
  glGenTextures(2, self->flutter_textures);
  for (gint i = 0; i < 2; i++) {
    glBindTexture(GL_TEXTURE_2D, self->flutter_textures[i]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, self->images[i]);
    if (old_images[i] != EGL_NO_IMAGE_KHR) {
      eglDestroyImageKHR(self->display, old_images[i]);
    }
  }
  glBindTexture(GL_TEXTURE_2D, binding);
}

// Renders mpv's frame into the back texture with mpv's context current, then
// makes it the front. Flutter's context is current before and after.
static void texture_gl_render(TextureGL* self, guint32 width, guint32 height) {
  gboolean resized = width != self->width || height != self->height;
  // Flutter's frames so far may still be reading the back texture; mpv's
  // context waits for them before drawing into it.
  EGLSyncKHR flutter_done = texture_gl_fence(self);
  GLCurrent flutter;
  if (!gl_switch_to(&flutter, self->display, self->surface, self->context,
                    EGL_OPENGL_ES_API)) {
    gl_switch_back(&flutter, self->display);
    if (flutter_done != EGL_NO_SYNC_KHR) {
      eglDestroySyncKHR(self->display, flutter_done);
    }
    return;
  }
  texture_gl_wait(self, flutter_done);
  EGLImageKHR old_images[2] = {EGL_NO_IMAGE_KHR, EGL_NO_IMAGE_KHR};
  if (resized) {
    texture_gl_create_targets(self, width, height, old_images);
  }
  guint32 back = 1 - self->front;
  mpv_opengl_fbo fbo{(gint32)self->framebuffers[back], (gint32)width,
                     (gint32)height, 0};
  int flip_y = 0;
  // Flutter presents on its own vsync; waiting here for the frame's due time
  // would hold up Flutter's raster thread (and every animation over the
  // video) for up to a frame.
  int block_for_target_time = 0;
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
      {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
      {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block_for_target_time},
      {MPV_RENDER_PARAM_INVALID, NULL},
  };
  mpv_render_context_render(self->render_context, params);
  // The frame must be complete before Flutter's context samples it.
  EGLSyncKHR mpv_done = texture_gl_fence(self);
  if (mpv_done == EGL_NO_SYNC_KHR) {
    glFinish();
  }
  gl_switch_back(&flutter, self->display);
  texture_gl_wait(self, mpv_done);
  if (resized) {
    texture_gl_import_targets(self, old_images);
  }
  self->front = back;
  if (resized) {
    // Notify Flutter about the change in texture's dimensions.
    video_output_notify_texture_update(self->video_output);
  }
}

void texture_gl_release(TextureGL* self) {
  g_mutex_lock(&self->mutex);
  if (self->render_context != NULL) {
    mpv_render_context_set_update_callback(self->render_context, NULL, NULL);
  }
  if (self->context != EGL_NO_CONTEXT) {
    GLCurrent previous;
    if (gl_switch_to(&previous, self->display, self->surface, self->context,
                     EGL_OPENGL_ES_API)) {
      texture_gl_delete_targets(self);
    } else {
      g_printerr("media_kit: TextureGL: Failed to make the EGL context current "
                 "to free it (0x%x).\n",
                 eglGetError());
    }
    // Without its context current (nothing is, then) mpv's GL calls do
    // nothing; its objects go with the context.
    if (self->render_context != NULL) {
      mpv_render_context_free(self->render_context);
      self->render_context = NULL;
    }
    gl_switch_back(&previous, self->display);
    for (gint i = 0; i < 2; i++) {
      if (self->images[i] != EGL_NO_IMAGE_KHR) {
        eglDestroyImageKHR(self->display, self->images[i]);
        self->images[i] = EGL_NO_IMAGE_KHR;
      }
    }
    // Flutter's textures of the images can only be deleted in Flutter's
    // context, which isn't current here; they go when Flutter's does.
    texture_gl_destroy_context(self);
  }
  self->video_output = NULL;
  g_mutex_unlock(&self->mutex);
}

gboolean texture_gl_populate_texture(FlTextureGL* texture,
                                     guint32* target,
                                     guint32* name,
                                     guint32* width,
                                     guint32* height,
                                     GError** error) {
  TextureGL* self = TEXTURE_GL(texture);
  g_mutex_lock(&self->mutex);
  if (self->video_output != NULL && self->render_context != NULL &&
      !self->failed && !self->checked) {
    // Flutter's context, current here, must be on mpv's display and able to
    // take EGLImages; else S/W rendering takes over.
    self->checked = TRUE;
    if (eglGetCurrentDisplay() != self->display ||
        eglGetCurrentContext() == EGL_NO_CONTEXT) {
      g_printerr("media_kit: TextureGL: Flutter renders on another EGL "
                 "display.\n");
      self->failed = TRUE;
    } else if (!epoxy_has_gl_extension("GL_OES_EGL_image")) {
      g_printerr("media_kit: TextureGL: Flutter's context can't use "
                 "EGLImages.\n");
      self->failed = TRUE;
    }
    if (self->failed) {
      video_output_fall_back_to_sw(self->video_output);
    }
  }
  if (self->video_output != NULL && self->render_context != NULL &&
      !self->failed) {
    gint64 required_width = video_output_get_width(self->video_output);
    gint64 required_height = video_output_get_height(self->video_output);
    if (required_width > 0 && required_height > 0) {
      texture_gl_render(self, (guint32)required_width,
                        (guint32)required_height);
    }
  }
  *target = GL_TEXTURE_2D;
  if (!self->failed && self->flutter_textures[self->front] != 0) {
    *name = self->flutter_textures[self->front];
    *width = self->width;
    *height = self->height;
  } else {
    // No frame yet: 1x1, in Flutter's context, binding put back.
    if (self->placeholder == 0) {
      GLint binding = 0;
      glGetIntegerv(GL_TEXTURE_BINDING_2D, &binding);
      const guint8 transparent[4] = {0, 0, 0, 0};
      glGenTextures(1, &self->placeholder);
      glBindTexture(GL_TEXTURE_2D, self->placeholder);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA,
                   GL_UNSIGNED_BYTE, transparent);
      glBindTexture(GL_TEXTURE_2D, binding);
    }
    *name = self->placeholder;
    *width = 1;
    *height = 1;
  }
  g_mutex_unlock(&self->mutex);
  return TRUE;
}
