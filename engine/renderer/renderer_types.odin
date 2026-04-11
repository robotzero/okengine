package renderer

import "../okmath"
import res "../resources"

renderer_backend_type :: enum {
	RENDERER_BACKEND_TYPE_VULKAN,
	RENDERER_BACKEND_TYPE_OPENGL,
	RENDERER_BACKEND_TYPE_DIRECTX,
}

builtin_renderpass :: enum u8 {
	WORLD = 0x01,
	UI    = 0x02,
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
update_global_world_state_proc :: #type proc(
	projection: okmath.mat4,
	view: okmath.mat4,
	view_position: okmath.vec3,
	ambient_colour: okmath.vec4,
	mode: i32,
)
update_global_ui_state_proc :: #type proc(
	projection: okmath.mat4,
	view: okmath.mat4,
	mode: i32,
)
draw_geometry_proc :: #type proc(data: geometry_render_data)
create_texture_proc :: #type proc(pixels: []u8, out_texture: ^res.texture)
destroy_texture_proc :: #type proc(texture: ^res.texture)
create_material_proc :: #type proc(material: ^res.material) -> bool
destroy_material_proc :: #type proc(material: ^res.material)
create_geometry_proc :: #type proc(
	geometry: ^res.geometry,
	vertex_count: u32,
	vertices: []okmath.vertex_3d,
	index_count: u32,
	indices: []u32,
) -> bool
destroy_geometry_proc :: #type proc(geometry: ^res.geometry)

global_uniform_object :: struct {
	projection:  okmath.mat4,
	view:        okmath.mat4,
	m_reserved0: okmath.mat4,
	m_reserved1: okmath.mat4,
}

renderer_backend :: struct {
	frame_number:              u64,
	initialize:                renderer_initialize_proc,
	shutdown:                  renderer_shutdown_proc,
	resized:                   renderer_resized_proc,
	begin_frame:               renderer_begin_frame_proc,
	end_frame:                 renderer_end_frame_proc,
	begin_renderpass:          begin_renderpass_proc,
	end_renderpass:            end_renderpass_proc,
	update_global_world_state: update_global_world_state_proc,
	update_global_ui_state:    update_global_ui_state_proc,
	draw_geometry:             draw_geometry_proc,
	create_texture:            create_texture_proc,
	destroy_texture:           destroy_texture_proc,
	create_material:           create_material_proc,
	destroy_material:          destroy_material_proc,
	create_geometry:           create_geometry_proc,
	destroy_geometry:          destroy_geometry_proc,
}

render_packet :: struct {
	delta_time:        f32,
	geometry_count:    u32,
	geometries:        []geometry_render_data,
	ui_geometry_count: u32,
	ui_geometries:     []geometry_render_data,
}

material_uniform_object :: struct {
	diffuse_color: okmath.vec4,
	v_reserved_0:  okmath.vec4,
	v_reserved_1:  okmath.vec4,
	v_reserved_2:  okmath.vec4,
}

geometry_render_data :: struct {
	model:    okmath.mat4,
	geometry: ^res.geometry,
}
