shader_type canvas_item;

// Affiche une photo recadrée (« cover », jamais déformée) avec les petits coins du design system.
uniform sampler2D photo : filter_linear, repeat_disable;
uniform vec2 photo_size = vec2(1.0, 1.0);
uniform vec2 rect_size = vec2(600.0, 300.0);
uniform float corner_radius = 4.0;

float rounded_box(vec2 p, vec2 half_size, float r) {
    vec2 q = abs(p) - half_size + vec2(r);
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    float rect_ratio = rect_size.x / max(rect_size.y, 1.0);
    float tex_ratio = photo_size.x / max(photo_size.y, 1.0);
    vec2 scale = vec2(1.0);
    if (tex_ratio > rect_ratio) {
        scale.x = rect_ratio / tex_ratio;
    } else {
        scale.y = tex_ratio / rect_ratio;
    }
    vec2 uv = (UV - 0.5) * scale + 0.5;
    vec4 c = texture(photo, uv);
    float d = rounded_box((UV - 0.5) * rect_size, rect_size * 0.5, corner_radius);
    COLOR = vec4(c.rgb, c.a * (1.0 - smoothstep(-1.0, 0.5, d)));
}
