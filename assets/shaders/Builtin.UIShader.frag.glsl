#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) flat in int in_mode;
layout(location = 1) in vec2 in_texcoord;

layout(set = 1, binding = 0) uniform local_uniform_object {
    vec4 diffuse_color;
    vec4 v_reserved_0;
    vec4 v_reserved_1;
    vec4 v_reserved_2;
} object_ubo;

layout(set = 1, binding = 1) uniform sampler2D diffuse_sampler;

layout(location = 0) out vec4 out_colour;

void main() {
    out_colour = object_ubo.diffuse_color * texture(diffuse_sampler, in_texcoord);
}
