#version 460 core

// Curvature and glow for the CRT effect's shader tier (retro-presentation
// design D6). Runs through ImageFilter.shader, on Impeller only.

#include <flutter/runtime_effect.glsl>

// Set by the engine: the size of the input.
uniform vec2 uSize;

// 0 is off.
uniform float uCurvature;
uniform float uGlow;

// 1 where this renderer hands over its input upside down (found by probing
// it at run time; backends differ).
uniform float uFlip;

// The frame in the input, in device pixels: the input is the whole screen.
uniform vec2 uCenter;
uniform vec2 uHalf;

// Set by the engine: what's behind the filter.
uniform sampler2D uInput;

out vec4 fragColor;

vec3 sampleAt(vec2 uv) {
  if (uFlip > 0.5) uv.y = 1.0 - uv.y;
  return texture(uInput, uv).rgb;
}

void main() {
  // A tube's bulge: further from the middle, further out.
  vec2 c = (FlutterFragCoord().xy - uCenter) / uHalf;
  c *= 1.0 + uCurvature * dot(c, c);
  if (abs(c.x) > 1.0 || abs(c.y) > 1.0) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }
  vec2 p = (uCenter + c * uHalf) / uSize;

  vec3 color = sampleAt(p);
  if (uGlow > 0.0) {
    // Bright parts bleed into their neighbours: eight taps around the pixel.
    vec2 r = 4.0 / uSize;
    vec3 blur = sampleAt(p + vec2(r.x, 0.0)) + sampleAt(p - vec2(r.x, 0.0)) +
        sampleAt(p + vec2(0.0, r.y)) + sampleAt(p - vec2(0.0, r.y)) +
        sampleAt(p + r) + sampleAt(p - r) +
        sampleAt(p + vec2(r.x, -r.y)) + sampleAt(p + vec2(-r.x, r.y));
    color += max(blur / 8.0 - 0.4, 0.0) * uGlow;
  }
  // Past 1.0 shows as a colour cast on wide-range render targets.
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
