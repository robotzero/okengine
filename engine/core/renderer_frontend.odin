package core

import "../okmath"

static_mesh_data :: struct {
}

renderer_system_state :: struct {
	backend:         renderer_backend,
	projection:      okmath.mat4,
	view:            okmath.mat4,
	near_clip:       f32,
	far_clip:        f32,
	default_texture: texture,
}

@(private = "file")
state_ptr: ^renderer_system_state
@(private = "file")
z: f32 = 0.0

renderer_system_initialize :: proc(
	application_name: string,
	state: ^renderer_system_state,
) -> bool {
	state_ptr = state
	// @TODO: make this configurable
	renderer_backend_create(.RENDERER_BACKEND_TYPE_VULKAN, &state_ptr.backend)
	state_ptr.backend.frame_number = 0

	if !state_ptr.backend.initialize(&state_ptr.backend, application_name) {
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
	// NOTE: Create default texture, a 256x256 blue/white checkerboard pattern.
	// This is done in code to eliminate asset dependencies.
	log_debug("Creating default texture...")
	tex_dimension :: 256
	channels :: 4
	pixel_count :: tex_dimension * tex_dimension
	pixels: [pixel_count * channels]u8 = {}
	kset_memory(&pixels, 255, int(size_of(pixels)))

	// Each pixel.
	for row: u32 = 0; row < tex_dimension; row += 1 {
		for col: u32 = 0; col < tex_dimension; col += 1 {
			index := row * tex_dimension + col
			index_bpp := index * channels
			if (row % 2) != 0 {
				if (col % 2) != 0 {
					pixels[index_bpp + 0] = 0
					pixels[index_bpp + 1] = 0
				}
			} else {
				if (col % 2) == 0 {
					pixels[index_bpp + 0] = 0
					pixels[index_bpp + 1] = 0
				}
			}
		}
	}
	pixels_slice := pixels[:]
	renderer_create_texture(
		"default",
		false,
		cast(i32)tex_dimension,
		cast(i32)tex_dimension,
		cast(i32)channels,
		&pixels_slice,
		false,
		&state_ptr.default_texture,
	)

	return true
}


renderer_system_shutdown :: proc(state: ^renderer_system_state) {
	if state_ptr != nil {
		renderer_destroy_texture(&state_ptr.default_texture)
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
		data.textures[0] = &state_ptr.default_texture
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
	name: cstring,
	auto_release: bool,
	width: i32,
	height: i32,
	channel_count: i32,
	pixels: ^[]u8,
	has_transparency: bool,
	out_texture: ^texture,
) {
	state_ptr.backend.create_texture(
		name,
		auto_release,
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

