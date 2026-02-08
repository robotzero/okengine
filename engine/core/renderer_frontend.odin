package core

import "../okmath"
import "core:fmt"
import "core:strings"
import si "vendor:stb/image"

static_mesh_data :: struct {
}

renderer_system_state :: struct {
	backend:      renderer_backend,
	projection:   okmath.mat4,
	view:         okmath.mat4,
	near_clip:    f32,
	far_clip:     f32,
	test_diffuse: ^texture,
}

@(private = "file")
state_ptr: ^renderer_system_state
@(private = "file")
z: f32 = 0.0
choice: i8 = 2

STB_IMAGE_IMPLEMENTATION :: 1

renderer_system_initialize :: proc(
	application_name: string,
	state: ^renderer_system_state,
	allocator := context.allocator,
) -> bool {
	state_ptr = state
	event_register(cast(u16)system_event_code.EVENT_CODE_DEBUG0, state_ptr, event_on_debug_event)

	// @TODO: make this configurable
	renderer_backend_create(.RENDERER_BACKEND_TYPE_VULKAN, &state_ptr.backend)
	state_ptr.backend.frame_number = 0

	if !state_ptr.backend.initialize(&state_ptr.backend, application_name, allocator) {
		log_fatal("Renderer backend failed to initialize. Shutting down")
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

	return true
}


renderer_system_shutdown :: proc(state: ^renderer_system_state) {
	if state_ptr != nil {
		state_ptr.backend.shutdown(&state_ptr.backend)
		event_unregister(
			cast(u16)system_event_code.EVENT_CODE_DEBUG0,
			state_ptr,
			event_on_debug_event,
		)
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
	// If the begin frame returned successfully, mid-frame operation may continue.
	if renderer_begin_frame(packet.delta_time) {
		state_ptr.backend.update_global_state(
			state_ptr.projection,
			state_ptr.view,
			okmath.vec3_zero(),
			okmath.vec4_one(),
			0,
		)
		model := okmath.mat4_translation(okmath.vec3{0, 0, 0})
		data: geometry_render_data = {}
		data.object_id = 0
		data.model = model
		if state_ptr.test_diffuse == nil {
			state_ptr.test_diffuse = texture_system_get_default_texture()
		}
		data.textures[0] = state_ptr.test_diffuse
		state_ptr.backend.update_object(data)
		// End the frame. If this fails, it is likely unrecoverable.
		result: bool = renderer_end_frame(packet.delta_time)

		if !result {
			log_error("renderer_end_frame failed. Application shutting down...")
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
		state_ptr.backend.resized(&state_ptr.backend, width, height)
	} else {
		log_warning("renderer backend does not exist to accept resize: %i %i", width, height)
	}
}

renderer_set_view :: proc(view: okmath.mat4) {
	state_ptr.view = view
}

renderer_create_texture :: proc(
	name: string,
	width: i32,
	height: i32,
	channel_count: i32,
	pixels: []u8,
	has_transparency: bool,
	out_texture: ^texture,
) {
	state_ptr.backend.create_texture(
		name,
		width,
		height,
		channel_count,
		pixels,
		has_transparency,
		out_texture,
	)
}

renderer_destroy_texture :: proc(texture: ^texture) {
	state_ptr.backend.destroy_texture(texture)
}

event_on_debug_event :: proc(
	code: u16,
	sender: rawptr,
	listener_inst: rawptr,
	data: event_context,
) -> bool {
	names := [3]string{"cobblestone", "paving", "paving2"}

	// Save off the old name
	old_name := names[choice]

	choice = choice + 1
	choice %= 3

	// Acquire the new texture
	state_ptr.test_diffuse = texture_system_acquire(names[choice], true)

	// Release the old texture
	texture_system_release(old_name)
	return true
}

