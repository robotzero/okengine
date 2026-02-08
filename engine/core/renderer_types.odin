package core

import "../okmath"

renderer_backend_type :: enum {
	RENDERER_BACKEND_TYPE_VULKAN,
	RENDERER_BACKEND_TYPE_OPENGL,
	RENDERER_BACKEND_TYPE_DIRECTX,
}

renderer_initialize_proc :: #type proc(
	backend: ^renderer_backend,
	application_name: string,
	allocator := context.allocator,
) -> bool
renderer_shutdown_proc :: #type proc(backend: ^renderer_backend)
renderer_resized_proc :: #type proc(backend: ^renderer_backend, width: u16, height: u16)
renderer_begin_frame_proc :: #type proc(backend: ^renderer_backend, delta_time: f32) -> bool
renderer_end_frame_proc :: #type proc(backend: ^renderer_backend, delta_time: f32) -> bool
update_global_state_proc :: #type proc(
	projection: okmath.mat4,
	view: okmath.mat4,
	view_position: okmath.vec3,
	ambient_colour: okmath.vec4,
	mode: i32,
)
update_object_proc :: #type proc(data: geometry_render_data)
create_texture_proc :: #type proc(
	name: string,
	width: i32,
	height: i32,
	channel_count: i32,
	pixels: []u8,
	has_transparency: bool,
	out_texture: ^texture,
)
destroy_texture_proc :: #type proc(texture: ^texture)

global_uniform_object :: struct {
	projection:  okmath.mat4,
	view:        okmath.mat4,
	m_reserved0: okmath.mat4,
	m_reserved1: okmath.mat4,
}

renderer_backend :: struct {
	frame_number:        u64,
	initialize:          renderer_initialize_proc,
	shutdown:            renderer_shutdown_proc,
	resized:             renderer_resized_proc,
	begin_frame:         renderer_begin_frame_proc,
	end_frame:           renderer_end_frame_proc,
	update_global_state: update_global_state_proc,
	update_object:       update_object_proc,
	create_texture:      create_texture_proc,
	destroy_texture:     destroy_texture_proc,
}

render_packet :: struct {
	delta_time: f32,
}

object_uniform_object :: struct {
	diffuse_color: okmath.vec4,
	v_reserved_0:  okmath.vec4,
	v_reserved_1:  okmath.vec4,
	v_reserved_2:  okmath.vec4,
}

geometry_render_data :: struct {
	object_id: u32,
	model:     okmath.mat4,
	textures:  [16]^texture,
}

