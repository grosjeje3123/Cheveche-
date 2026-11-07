shader_type canvas_item;

// Couche mate à gratter. Aucun dégradé : la matière est une teinte plate, travaillée par du grain.
uniform sampler2D mask_tex : filter_linear, repeat_disable;   // 0 = intact, 1 = gratté
uniform vec2 rect_size = vec2(600.0, 400.0);
uniform float corner_radius = 4.0;
uniform vec4 slate : source_color = vec4(0.204, 0.259, 0.227, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;          // dissolution finale, à la réponse

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

float rounded_box(vec2 p, vec2 half_size, float r) {
    vec2 q = abs(p) - half_size + vec2(r);
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
    vec2 px = UV * rect_size;
    // Bord irrégulier : la matière se déchire, elle ne se découpe pas au compas.
    float tear = (vnoise(px / 5.0) - 0.5) * 0.30 + (vnoise(px / 14.0) - 0.5) * 0.22;
    float v = clamp(texture(mask_tex, UV).r + tear * smoothstep(0.0, 0.25, texture(mask_tex, UV).r), 0.0, 1.0);

    // La matière s'amincit progressivement quand on frotte.
    float cover_a = 1.0 - smoothstep(0.30, 0.62, v);

    // Dissolution finale : la matière s'effrite par plaques, du grain vers le vide.
    float n = vnoise(px / 3.5) * 0.55 + vnoise(px / 10.0) * 0.45;
    float thr = dissolve * 1.3 - 0.15;
    cover_a *= smoothstep(thr - 0.10, thr + 0.10, n);

    // Surface : teinte plate + marbrure large + fibres + grain + un peu de poudre claire.
    vec3 base = slate.rgb;
    base += (vnoise(px / 110.0) - 0.5) * 0.05;
    base += (vnoise(vec2(px.x / 90.0, px.y / 2.2)) - 0.5) * 0.040;
    base += (hash(floor(px)) - 0.5) * 0.045;
    base += smoothstep(0.80, 0.94, vnoise(px / 3.0)) * 0.035;

    // Tranche de la matière entamée : liseré un peu plus clair.
    float rim = clamp(1.0 - abs(v - 0.46) * 7.0, 0.0, 1.0);
    base = mix(base, slate.rgb * 1.30 + vec3(0.04), rim * 0.45);

    // Ombre portée de la matière sur le papier, juste au bord du grattage.
    float shadow_a = smoothstep(0.58, 0.68, v) * (1.0 - smoothstep(0.68, 0.95, v)) * 0.22;
    vec3 shadow_col = vec3(0.10, 0.12, 0.11);

    float d = rounded_box(px - rect_size * 0.5, rect_size * 0.5, corner_radius);
    float shape = 1.0 - smoothstep(-1.0, 0.5, d);

    float a_cover = cover_a * shape;
    float a_shadow = shadow_a * shape * (1.0 - cover_a) * (1.0 - dissolve);
    float a = a_cover + a_shadow;
    COLOR = vec4((base * a_cover + shadow_col * a_shadow) / max(a, 0.0001), a);
}
