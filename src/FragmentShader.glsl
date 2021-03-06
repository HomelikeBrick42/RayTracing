#version 440 core

layout(location = 0) out vec4 o_Color;

layout(location = 0) in vec2 v_UV;

uniform sampler2D u_Texture;
uniform uint u_Samples;

void main() {
    float scale = 1.0 / float(u_Samples);
    o_Color = vec4(clamp(sqrt(texture(u_Texture, v_UV).rgb * scale), vec3(0.0), vec3(1.0)), 1.0);
}
