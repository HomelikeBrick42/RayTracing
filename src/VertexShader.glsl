#version 440 core

layout(location = 0) out vec2 v_UV;

uniform uvec2 u_ScreenSize;
uniform uvec2 u_ImageSize;

void main() {
    vec2 uv = vec2(
        (gl_VertexID >> 0) & 1,
        (gl_VertexID >> 1) & 1
    );
    v_UV = uv;

    vec2 coord = uv * 2.0 - 1.0;
    if (u_ScreenSize.x > u_ScreenSize.y) {
        coord.x *= (float(u_ImageSize.x) / float(u_ImageSize.y)) / (float(u_ScreenSize.x) / float(u_ScreenSize.y));
    } else {
        coord.y *= (float(u_ImageSize.y) / float(u_ImageSize.x)) / (float(u_ScreenSize.y) / float(u_ScreenSize.x));
    }
    gl_Position = vec4(coord, 0.0, 1.0);
}
