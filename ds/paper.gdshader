shader_type canvas_item;

// Fond de papier : ivoire plat, avec une texture à peine perceptible (grain, fibres, marbrure).
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec4 ivory : source_color = vec4(0.945, 0.929, 0.890, 1.0);
uniform float grain : hint_range(0.0, 0.05) = 0.016;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
    vec2 px = UV * rect_size;
    float g = hash(floor(px)) - 0.5;
    float fibre = vnoise(vec2(px.x / 26.0, px.y / 1.6)) - 0.5;
    float mott = vnoise(px / 160.0) - 0.5;
    COLOR = vec4(ivory.rgb + vec3(g * grain + fibre * grain * 0.7 + mott * grain * 1.3), 1.0);
}
