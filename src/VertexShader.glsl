#version 440 core

layout(location = 0) out vec2 v_UV;

void main() {
    vec2 uv = vec2(
        (gl_VertexID >> 0) & 1,
        (gl_VertexID >> 1) & 1
    );
    v_UV = uv;
    gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
}
