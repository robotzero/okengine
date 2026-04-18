package renderer

import e "../core/event"
import l "../logger"
import "../okmath"
import res "../resources"

static_mesh_data :: struct {
}

renderer_system_state :: struct {
	backend:            renderer_backend,
	projection:         okmath.mat4,
	view:               okmath.mat4,
	view_position:      okmath.vec3,
	near_clip:          f32,
	far_clip:           f32,
	ui_projection:      okmath.mat4,
	ui_view:            okmath.mat4,
	material_shader_id: u32,
	ui_shader_id:       u32,
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
	state_ptr.material_shader_id = res.INVALID_ID
	state_ptr.ui_shader_id = res.INVALID_ID

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

// Called by the material system to register shader IDs so draw_frame can route by them.
renderer_set_material_shader_id :: proc(id: u32) {
	if state_ptr != nil {
		state_ptr.material_shader_id = id
	}
}

renderer_set_ui_shader_id :: proc(id: u32) {
	if state_ptr != nil {
		state_ptr.ui_shader_id = id
	}
}

renderer_get_projection :: proc() -> okmath.mat4 {
	return state_ptr.projection
}

renderer_get_view :: proc() -> okmath.mat4 {
	return state_ptr.view
}

renderer_get_ui_projection :: proc() -> okmath.mat4 {
	return state_ptr.ui_projection
}

renderer_get_ui_view :: proc() -> okmath.mat4 {
	return state_ptr.ui_view
}

renderer_draw_frame :: proc(
	packet: ^render_packet,
	apply_material_globals: proc(shader_id: u32, proj, view: ^okmath.mat4, view_position: ^okmath.vec3) -> bool,
	apply_material_instance: proc(m: ^res.material) -> bool,
	apply_material_local: proc(m: ^res.material, model: ^okmath.mat4) -> bool,
	use_shader_by_id: proc(id: u32) -> bool,
	get_default_material: proc() -> ^res.material,
) -> bool {
	if renderer_begin_frame(packet.delta_time) {
		// World renderpass
		if !state_ptr.backend.begin_renderpass(&state_ptr.backend, u8(builtin_renderpass.WORLD)) {
			l.log_error("renderer_draw_frame: begin_renderpass(WORLD) failed.")
			return false
		}

		if !use_shader_by_id(state_ptr.material_shader_id) {
			l.log_error("renderer_draw_frame: failed to use material shader.")
			return false
		}

		proj := state_ptr.projection
		view := state_ptr.view
		view_pos := state_ptr.view_position
		if !apply_material_globals(state_ptr.material_shader_id, &proj, &view, &view_pos) {
			l.log_error("renderer_draw_frame: failed to apply material shader globals.")
			return false
		}

		for i in 0 ..< packet.geometry_count {
			m: ^res.material
			if packet.geometries[i].geometry.material != nil {
				m = packet.geometries[i].geometry.material
			} else {
				m = get_default_material()
			}

			if !apply_material_instance(m) {
				l.log_warning("renderer_draw_frame: failed to apply material '%s'. Skipping draw.", m.name)
				continue
			}

			model := packet.geometries[i].model
			apply_material_local(m, &model)

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

		if !use_shader_by_id(state_ptr.ui_shader_id) {
			l.log_error("renderer_draw_frame: failed to use UI shader.")
			return false
		}

		ui_proj := state_ptr.ui_projection
		ui_view := state_ptr.ui_view
		if !apply_material_globals(state_ptr.ui_shader_id, &ui_proj, &ui_view, nil) {
			l.log_error("renderer_draw_frame: failed to apply UI shader globals.")
			return false
		}

		for i in 0 ..< packet.ui_geometry_count {
			m: ^res.material
			if packet.ui_geometries[i].geometry.material != nil {
				m = packet.ui_geometries[i].geometry.material
			} else {
				m = get_default_material()
			}

			if !apply_material_instance(m) {
				l.log_warning("renderer_draw_frame: failed to apply UI material '%s'. Skipping draw.", m.name)
				continue
			}

			model := packet.ui_geometries[i].model
			apply_material_local(m, &model)

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

renderer_set_view :: proc(view: okmath.mat4, view_position: okmath.vec3) {
	state_ptr.view = view
	state_ptr.view_position = view_position
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

renderer_create_geometry :: proc(
	geometry: ^res.geometry,
	vertex_count: u32,
	vertex_size: u32,
	vertices: rawptr,
	index_count: u32,
	index_size: u32,
	indices: rawptr,
) -> bool {
	return state_ptr.backend.create_geometry(geometry, vertex_count, vertex_size, vertices, index_count, index_size, indices)
}

renderer_destroy_geometry :: proc(geometry: ^res.geometry) {
	state_ptr.backend.destroy_geometry(geometry)
}

// ── Shader forwarding ─────────────────────────────────────────────────────────

renderer_shader_create :: proc(
	s: ^res.shader,
	renderpass_id: u8,
	stage_count: u8,
	stage_filenames: []string,
	stages: []res.shader_stage,
) -> bool {
	return state_ptr.backend.shader_create(s, renderpass_id, stage_count, stage_filenames, stages)
}

renderer_shader_destroy :: proc(s: ^res.shader) {
	state_ptr.backend.shader_destroy(s)
}

renderer_shader_initialize :: proc(s: ^res.shader) -> bool {
	return state_ptr.backend.shader_initialize(s)
}

renderer_shader_use :: proc(s: ^res.shader) -> bool {
	return state_ptr.backend.shader_use(s)
}

renderer_shader_bind_globals :: proc(s: ^res.shader) -> bool {
	return state_ptr.backend.shader_bind_globals(s)
}

renderer_shader_bind_instance :: proc(s: ^res.shader, instance_id: u32) -> bool {
	return state_ptr.backend.shader_bind_instance(s, instance_id)
}

renderer_shader_apply_globals :: proc(s: ^res.shader) -> bool {
	return state_ptr.backend.shader_apply_globals(s)
}

renderer_shader_apply_instance :: proc(s: ^res.shader) -> bool {
	return state_ptr.backend.shader_apply_instance(s)
}

renderer_shader_acquire_instance_resources :: proc(s: ^res.shader, out_instance_id: ^u32) -> bool {
	return state_ptr.backend.shader_acquire_instance_resources(s, out_instance_id)
}

renderer_shader_release_instance_resources :: proc(s: ^res.shader, instance_id: u32) -> bool {
	return state_ptr.backend.shader_release_instance_resources(s, instance_id)
}

renderer_set_uniform :: proc(s: ^res.shader, uniform: ^res.shader_uniform, value: rawptr) -> bool {
	return state_ptr.backend.shader_set_uniform(s, uniform, value)
}
