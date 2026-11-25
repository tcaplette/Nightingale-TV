#include "youtube_view.h"

#include <webkit2/webkit2.h>

#include <cstring>

namespace {

struct YouTubeView {
  GtkOverlay* overlay = nullptr;
  FlView* flutter = nullptr;
  FlMethodChannel* channel = nullptr;
  WebKitWebView* web = nullptr;
  // Where the player sits, in the Flutter view's logical pixels.
  GdkRectangle frame{0, 0, 0, 0};
  // Whether the app shows the player now; kept for a view made later.
  bool shown = false;
};

YouTubeView* g_view = nullptr;

void send(const char* method, FlValue* args) {
  fl_method_channel_invoke_method(g_view->channel, method, args, nullptr, nullptr, nullptr);
}

gboolean child_position(GtkOverlay*, GtkWidget* widget, GdkRectangle* allocation, gpointer) {
  if (g_view->web == nullptr || widget != GTK_WIDGET(g_view->web)) return FALSE;
  *allocation = g_view->frame;
  return TRUE;
}

// The player never keeps key focus: the D-pad, number and media keys stay
// with the app.
gboolean give_focus_back(GtkWidget*, GdkEvent*, gpointer) {
  gtk_widget_grab_focus(GTK_WIDGET(g_view->flutter));
  return FALSE;
}

void on_script_message(WebKitUserContentManager*, WebKitJavascriptResult* result, gpointer) {
  JSCValue* value = webkit_javascript_result_get_js_value(result);
  if (!jsc_value_is_string(value)) return;
  g_autofree gchar* text = jsc_value_to_string(value);
  send("message", fl_value_new_string(text));
}

void on_terminated(WebKitWebView*, WebKitWebProcessTerminationReason reason, gpointer) {
  send("crashed", fl_value_new_int(reason));
}

// Links the player opens (YouTube's logo, a video title) go to the browser,
// never into the player's frame.
gboolean on_decide_policy(WebKitWebView*, WebKitPolicyDecision* decision, WebKitPolicyDecisionType type,
                          gpointer) {
  if (type != WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) return FALSE;
  WebKitNavigationAction* action =
      webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
  const gchar* uri = webkit_uri_request_get_uri(webkit_navigation_action_get_request(action));
  if (uri != nullptr) send("openUrl", fl_value_new_string(uri));
  webkit_policy_decision_ignore(decision);
  return TRUE;
}

void create_view() {
  WebKitWebContext* context = webkit_web_context_new_ephemeral();
  WebKitUserContentManager* content = webkit_user_content_manager_new();
  g_signal_connect(content, "script-message-received::ntv", G_CALLBACK(on_script_message), nullptr);
  webkit_user_content_manager_register_script_message_handler(content, "ntv");
  WebKitWebsitePolicies* policies = webkit_website_policies_new_with_policies("autoplay", WEBKIT_AUTOPLAY_ALLOW, nullptr);
  g_view->web = WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW, "web-context", context, "user-content-manager",
                                             content, "website-policies", policies, nullptr));
  g_object_unref(context);
  g_object_unref(content);
  g_object_unref(policies);

  WebKitSettings* settings = webkit_web_view_get_settings(g_view->web);
  webkit_settings_set_media_playback_requires_user_gesture(settings, FALSE);
  webkit_settings_set_enable_fullscreen(settings, FALSE);
  webkit_settings_set_javascript_can_open_windows_automatically(settings, FALSE);

  GdkRGBA black{0, 0, 0, 1};
  webkit_web_view_set_background_color(g_view->web, &black);

  GtkWidget* widget = GTK_WIDGET(g_view->web);
  gtk_widget_set_can_focus(widget, FALSE);
  g_signal_connect(widget, "focus-in-event", G_CALLBACK(give_focus_back), nullptr);
  g_signal_connect(g_view->web, "web-process-terminated", G_CALLBACK(on_terminated), nullptr);
  g_signal_connect(g_view->web, "decide-policy", G_CALLBACK(on_decide_policy), nullptr);
  gtk_overlay_add_overlay(g_view->overlay, widget);
  gtk_widget_set_visible(widget, g_view->shown);
}

int64_t int_arg(FlValue* args, const char* key) {
  FlValue* v = fl_value_lookup_string(args, key);
  if (v == nullptr) return 0;
  if (fl_value_get_type(v) == FL_VALUE_TYPE_INT) return fl_value_get_int(v);
  if (fl_value_get_type(v) == FL_VALUE_TYPE_FLOAT) return static_cast<int64_t>(fl_value_get_float(v) + 0.5);
  return 0;
}

const gchar* string_arg(FlValue* args, const char* key) {
  FlValue* v = fl_value_lookup_string(args, key);
  return v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_STRING ? fl_value_get_string(v) : nullptr;
}

void on_method(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  const bool map = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP;

  if (strcmp(method, "load") == 0 && map) {
    // A renderer that stopped is replaced by a new view.
    if (g_view->web != nullptr && webkit_web_view_get_is_web_process_responsive(g_view->web) == FALSE) {
      gtk_widget_destroy(GTK_WIDGET(g_view->web));
      g_view->web = nullptr;
    }
    if (g_view->web == nullptr) create_view();
    webkit_web_view_load_html(g_view->web, string_arg(args, "html"), string_arg(args, "baseUrl"));
  } else if (strcmp(method, "recreate") == 0) {
    if (g_view->web != nullptr) gtk_widget_destroy(GTK_WIDGET(g_view->web));
    g_view->web = nullptr;
  } else if (strcmp(method, "frame") == 0 && map) {
    g_view->frame = GdkRectangle{static_cast<int>(int_arg(args, "x")), static_cast<int>(int_arg(args, "y")),
                                 static_cast<int>(int_arg(args, "w")), static_cast<int>(int_arg(args, "h"))};
    FlValue* visible = fl_value_lookup_string(args, "visible");
    const bool show = visible != nullptr && fl_value_get_type(visible) == FL_VALUE_TYPE_BOOL &&
                      fl_value_get_bool(visible) && g_view->frame.width > 0 && g_view->frame.height > 0;
    g_view->shown = show;
    if (g_view->web != nullptr) {
      GtkWidget* widget = GTK_WIDGET(g_view->web);
      if (show) {
        gtk_widget_show(widget);
        gtk_widget_queue_resize(widget);
      } else {
        gtk_widget_hide(widget);
      }
    }
  } else if (strcmp(method, "run") == 0 && map) {
    if (g_view->web != nullptr) {
      webkit_web_view_evaluate_javascript(g_view->web, string_arg(args, "js"), -1, nullptr, nullptr, nullptr,
                                          nullptr, nullptr);
    }
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  fl_method_call_respond_success(call, nullptr, nullptr);
}

}  // namespace

void youtube_view_register(GtkOverlay* overlay, FlView* view) {
  g_view = new YouTubeView();
  g_view->overlay = overlay;
  g_view->flutter = view;
  g_signal_connect(overlay, "get-child-position", G_CALLBACK(child_position), nullptr);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_view->channel = fl_method_channel_new(messenger, "ntv/youtube_view", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(g_view->channel, on_method, nullptr, nullptr);
}
