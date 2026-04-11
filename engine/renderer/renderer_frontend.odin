package renderer

import e "../core/event"
import l "../logger"
import "../okmath"
import res "../resources"

static_mesh_data :: struct {
}

renderer_system_state :: struct {
	backend:       renderer_backend,
	projection:    okmath.mat4,
	view:          okmath.mat4,
	near_clip:     f32,
	far_clip:      f32,
	ui_projection: okmath.mat4,
	ui_view:       okmath.mat4,
}

@(private = "file")
state_ptr: ^renderer_system_state

renderer_system_initialize :: proc(
	application_name: string,
	state: ^renderer_system_state,
	framebuffer_width: u32,
	framebuffer_height: u32,
	allocator := context.allocator,
) -> bool {
	state_ptr = state
	state_ptr.backend.frame_number = 0

	if !state_ptr.backend.initialize(&state_ptr.backend, application_name, framebuffer_width, framebuffer_height, allocator) {
		l.log_fatal("Renderer backend failed to initialize. Shutting down")
		return false
	}

	state_ptr.near_clip = 0.1
	state_ptr.far_clip = 1000.0
	state_ptr.projection = okmath.mat4_perspective(
		okmath.deg_to_rad(45.0),
		1280 / 720.0,
		state_ptr.near_clip,
		state_ptr.far_clip,
	)
	state_ptr.view = okmath.mat4_translation(okmath.vec3{0, 0, -30.0})
	state_ptr.view = okmath.mat4_inverse(state_ptr.view)

	// UI projection: orthographic, y-down (top-left origin).
	state_ptr.ui_projection = okmath.mat4_orthographic(
		0,
		f32(framebuffer_width),
		f32(framebuffer_height),
		0,
		-100.0,
		100.0,
	)
	state_ptr.ui_view = okmath.mat4_inverse(okmath.mat4_identity())

	return true
}


renderer_system_shutdown :: proc(state: ^renderer_system_state) {
	if state_ptr != nil {
		state_ptr.backend.shutdown(&state_ptr.backend)
	}
	state_ptr = nil
}

renderer_begin_frame :: proc(delta_time: f32) -> bool {
	if state_ptr != nil {
		return state_ptr.backend.begin_frame(&state_ptr.backend, delta_time)
	}
	return false
}

renderer_end_frame :: proc(delta_time: f32) -> bool {
	if state_ptr == nil {
		return false
	}
	result: bool = state_ptr.backend.end_frame(&state_ptr.backend, delta_time)
	state_ptr.backend.frame_number = state_ptr.backend.frame_number + 1
	return result
}

renderer_draw_frame :: proc(packet: ^render_packet) -> bool {
	if renderer_begin_frame(packet.delta_time) {
		// World renderpass
		if !state_ptr.backend.begin_renderpass(&state_ptr.backend, u8(builtin_renderpass.WORLD)) {
			l.log_error("renderer_draw_frame: begin_renderpass(WORLD) failed.")
			return false
		}

		state_ptr.backend.update_global_world_state(
			state_ptr.projection,
			state_ptr.view,
			okmath.vec3_zero(),
			okmath.vec4_one(),
			0,
		)

		for i in 0 ..< packet.geometry_count {
			state_ptr.backend.draw_geometry(packet.geometries[i])
		}

		if !state_ptr.backend.end_renderpass(&state_ptr.backend, u8(builtin_renderpass.WORLD)) {
			l.log_error("renderer_draw_frame: end_renderpass(WORLD) failed.")
			return false
		}

		// UI renderpass
		if !state_ptr.backend.begin_renderpass(&state_ptr.backend, u8(builtin_renderpass.UI)) {
			l.log_error("renderer_draw_frame: begin_renderpass(UI) failed.")
			return false
		}

		state_ptr.backend.update_global_ui_state(
			state_ptr.ui_projection,
			state_ptr.ui_view,
			0,
		)

		for i in 0 ..< packet.ui_geometry_count {
			state_ptr.backend.draw_geometry(packet.ui_geometries[i])
		}

		if !state_ptr.backend.end_renderpass(&state_ptr.backend, u8(builtin_renderpass.UI)) {
			l.log_error("renderer_draw_frame: end_renderpass(UI) failed.")
			return false
		}

		result := renderer_end_frame(packet.delta_time)
		if !result {
			l.log_error("renderer_end_frame failed. Application shutting down...")
			return false
		}
	}

	return true
}

renderer_on_resized :: proc(width: u16, height: u16) {
	if state_ptr != nil {
		state_ptr.projection = okmath.mat4_perspective(
			okmath.deg_to_rad(45.0),
			f32(width) / f32(height),
			state_ptr.near_clip,
			state_ptr.far_clip,
		)
		state_ptr.ui_projection = okmath.mat4_orthographic(
			0,
			f32(width),
			f32(height),
			0,
			-100.0,
			100.0,
		)
		state_ptr.backend.resized(&state_ptr.backend, width, height)
	} else {
		l.log_warning("renderer backend does not exist to accept resize: %i %i", width, height)
	}
}

renderer_set_view :: proc(view: okmath.mat4) {
	state_ptr.view = view
}

renderer_set_ui_view :: proc(view: okmath.mat4) {
	state_ptr.ui_view = view
}

renderer_create_texture :: proc(pixels: []u8, out_texture: ^res.texture) {
	state_ptr.backend.create_texture(pixels, out_texture)
}

renderer_destroy_texture :: proc(texture: ^res.texture) {
	state_ptr.backend.destroy_texture(texture)
}

renderer_create_material :: proc(material: ^res.material) -> bool {
	return state_ptr.backend.create_material(material)
}

renderer_destroy_material :: proc(material: ^res.material) {
	state_ptr.backend.destroy_material(material)
}

renderer_create_geometry :: proc(
	geometry: ^res.geometry,
	vertex_count: u32,
	vertices: []okmath.vertex_3d,
	index_count: u32,
	indices: []u32,
) -> bool {
	return state_ptr.backend.create_geometry(geometry, vertex_count, vertices, index_count, indices)
}

renderer_destroy_geometry :: proc(geometry: ^res.geometry) {
	state_ptr.backend.destroy_geometry(geometry)
}
