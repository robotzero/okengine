package renderer

import "../okmath"
import res "../resources"

BUILTIN_SHADER_NAME_MATERIAL :: "Shader.Builtin.Material"
BUILTIN_SHADER_NAME_UI :: "Shader.Builtin.UI"

renderer_backend_type :: enum {
	RENDERER_BACKEND_TYPE_VULKAN,
	RENDERER_BACKEND_TYPE_OPENGL,
	RENDERER_BACKEND_TYPE_DIRECTX,
}

builtin_renderpass :: enum u8 {
	WORLD = 0x01,
	UI    = 0x02,
}

renderer_debug_view_mode :: enum i32 {
	DEFAULT  = 0,
	LIGHTING = 1,
	NORMALS  = 2,
}

renderer_initialize_proc :: #type proc(
	backend: ^renderer_backend,
	application_name: string,
	framebuffer_width: u32,
	framebuffer_height: u32,
	allocator := context.allocator,
) -> bool
renderer_shutdown_proc :: #type proc(backend: ^renderer_backend)
renderer_resized_proc :: #type proc(backend: ^renderer_backend, width: u16, height: u16)
renderer_begin_frame_proc :: #type proc(backend: ^renderer_backend, delta_time: f32) -> bool
renderer_end_frame_proc :: #type proc(backend: ^renderer_backend, delta_time: f32) -> bool
begin_renderpass_proc :: #type proc(backend: ^renderer_backend, renderpass_id: u8) -> bool
end_renderpass_proc :: #type proc(backend: ^renderer_backend, renderpass_id: u8) -> bool
draw_geometry_proc :: #type proc(data: geometry_render_data)
create_texture_proc :: #type proc(pixels: []u8, out_texture: ^res.texture)
destroy_texture_proc :: #type proc(texture: ^res.texture)
create_geometry_proc :: #type proc(
	geometry: ^res.geometry,
	vertex_count: u32,
	vertex_size: u32,
	vertices: rawptr,
	index_count: u32,
	index_size: u32,
	indices: rawptr,
) -> bool
destroy_geometry_proc :: #type proc(geometry: ^res.geometry)

// Shader backend proc types
shader_create_proc :: #type proc(
	s: ^res.shader,
	renderpass_id: u8,
	stage_count: u8,
	stage_filenames: []string,
	stages: []res.shader_stage,
) -> bool
shader_destroy_proc :: #type proc(s: ^res.shader)
shader_initialize_proc :: #type proc(s: ^res.shader) -> bool
shader_use_proc :: #type proc(s: ^res.shader) -> bool
shader_bind_globals_proc :: #type proc(s: ^res.shader) -> bool
shader_bind_instance_proc :: #type proc(s: ^res.shader, instance_id: u32) -> bool
shader_apply_globals_proc :: #type proc(s: ^res.shader) -> bool
shader_apply_instance_proc :: #type proc(s: ^res.shader) -> bool
shader_acquire_instance_resources_proc :: #type proc(s: ^res.shader, out_instance_id: ^u32) -> bool
shader_release_instance_resources_proc :: #type proc(s: ^res.shader, instance_id: u32) -> bool
shader_set_uniform_proc :: #type proc(
	s: ^res.shader,
	uniform: ^res.shader_uniform,
	value: rawptr,
) -> bool

renderer_backend :: struct {
	frame_number:                       u64,
	initialize:                         renderer_initialize_proc,
	shutdown:                           renderer_shutdown_proc,
	resized:                            renderer_resized_proc,
	begin_frame:                        renderer_begin_frame_proc,
	end_frame:                          renderer_end_frame_proc,
	begin_renderpass:                   begin_renderpass_proc,
	end_renderpass:                     end_renderpass_proc,
	draw_geometry:                      draw_geometry_proc,
	create_texture:                     create_texture_proc,
	destroy_texture:                    destroy_texture_proc,
	create_geometry:                    create_geometry_proc,
	destroy_geometry:                   destroy_geometry_proc,
	shader_create:                      shader_create_proc,
	shader_destroy:                     shader_destroy_proc,
	shader_initialize:                  shader_initialize_proc,
	shader_use:                         shader_use_proc,
	shader_bind_globals:                shader_bind_globals_proc,
	shader_bind_instance:               shader_bind_instance_proc,
	shader_apply_globals:               shader_apply_globals_proc,
	shader_apply_instance:              shader_apply_instance_proc,
	shader_acquire_instance_resources:  shader_acquire_instance_resources_proc,
	shader_release_instance_resources:  shader_release_instance_resources_proc,
	shader_set_uniform:                 shader_set_uniform_proc,
}

render_packet :: struct {
	delta_time:        f32,
	geometry_count:    u32,
	geometries:        []geometry_render_data,
	ui_geometry_count: u32,
	ui_geometries:     []geometry_render_data,
}

geometry_render_data :: struct {
	model:    okmath.mat4,
	geometry: ^res.geometry,
}
