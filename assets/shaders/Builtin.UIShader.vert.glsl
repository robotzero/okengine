#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec2 in_position;
layout(location = 1) in vec2 in_texcoord;

layout(set = 0, binding = 0) uniform global_uniform_object {
    mat4 projection;
    mat4 view;
    mat4 m_reserved0;
    mat4 m_reserved1;
} global_ubo;

layout(push_constant) uniform push_constants {
    mat4 model;
} u_push_constants;

layout(location = 0) out int out_mode;
layout(location = 1) out vec2 out_texcoord;

void main() {
    out_texcoord = in_texcoord;
    out_mode = 0;
    gl_Position = global_ubo.projection * global_ubo.view * u_push_constants.model * vec4(in_position, 0.0, 1.0);
}
