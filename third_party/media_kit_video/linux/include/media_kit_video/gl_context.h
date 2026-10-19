// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef GL_CONTEXT_H_
#define GL_CONTEXT_H_

// Switching the calling thread to mpv's EGL context and back.
//
// Flutter renders with its own EGL context on its raster thread, on X11 and
// Wayland alike. GDK's contexts (GLX on X11) are only current on the main
// thread. libglvnd lets a thread have an EGL or a GLX context current, not
// both, so a current GLX context is released before mpv's and restored after.

#include <epoxy/egl.h>
#include <epoxy/gl.h>
#include <gtk/gtk.h>

#ifdef GDK_WINDOWING_X11
#include <epoxy/glx.h>
#include <gdk/gdkx.h>
#endif

typedef struct _GLCurrent {
  EGLenum egl_api;
  EGLDisplay egl_display;
  EGLSurface egl_draw;
  EGLSurface egl_read;
  EGLContext egl_context;
  GdkGLContext* gdk; /* Not referenced. */
#ifdef GDK_WINDOWING_X11
  Display* glx_display;
  GLXDrawable glx_draw;
  GLXDrawable glx_read;
  GLXContext glx_context;
#endif
} GLCurrent;

static inline gboolean gl_display_is_x11() {
#ifdef GDK_WINDOWING_X11
  return GDK_IS_X11_DISPLAY(gdk_display_get_default());
#else
  return FALSE;
#endif
}

/**
 * @brief Saves what is current on this thread in |saved| and makes |context|
 * (of |api|) current. On failure, call |gl_switch_back| all the same.
 */
static inline gboolean gl_switch_to(GLCurrent* saved,
                                    EGLDisplay display,
                                    EGLSurface surface,
                                    EGLContext context,
                                    EGLenum api) {
  saved->egl_api = eglQueryAPI();
  saved->egl_display = eglGetCurrentDisplay();
  saved->egl_draw = eglGetCurrentSurface(EGL_DRAW);
  saved->egl_read = eglGetCurrentSurface(EGL_READ);
  saved->egl_context = eglGetCurrentContext();
  saved->gdk = NULL;
#ifdef GDK_WINDOWING_X11
  saved->glx_display = NULL;
  saved->glx_draw = None;
  saved->glx_read = None;
  saved->glx_context = NULL;
  if (gl_display_is_x11() && glXGetCurrentContext() != NULL) {
    saved->glx_display = glXGetCurrentDisplay();
    saved->glx_draw = glXGetCurrentDrawable();
    saved->glx_read = glXGetCurrentReadDrawable();
    saved->glx_context = glXGetCurrentContext();
    // Through GDK when it's GDK's, so GDK's record of it stays right.
    saved->gdk = gdk_gl_context_get_current();
    if (saved->gdk != NULL) {
      gdk_gl_context_clear_current();
    } else {
      glXMakeContextCurrent(saved->glx_display, None, None, NULL);
    }
  }
#endif
  eglBindAPI(api);
  return eglMakeCurrent(display, surface, surface, context);
}

/**
 * @brief Releases mpv's context (on |display|) and puts back what |saved| holds.
 */
static inline void gl_switch_back(const GLCurrent* saved, EGLDisplay display) {
  eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  eglBindAPI(saved->egl_api);
  if (saved->egl_context != EGL_NO_CONTEXT) {
    eglMakeCurrent(saved->egl_display, saved->egl_draw, saved->egl_read,
                   saved->egl_context);
  }
#ifdef GDK_WINDOWING_X11
  if (saved->glx_context != NULL) {
    if (saved->gdk != NULL) {
      gdk_gl_context_make_current(saved->gdk);
    } else {
      glXMakeContextCurrent(saved->glx_display, saved->glx_draw,
                            saved->glx_read, saved->glx_context);
    }
  }
#endif
}

#endif  // GL_CONTEXT_H_
