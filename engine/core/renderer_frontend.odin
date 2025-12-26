package core

static_mesh_data :: struct {
}

renderer_system_state :: struct {
	backend: renderer_backend,
}

state_ptr: ^renderer_system_state

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
	// If the begin frame returned successfully, mid-frame operation may continue.
	if renderer_begin_frame(packet.delta_time) {
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
		state_ptr.backend.resized(&state_ptr.backend, width, height)
	} else {
		log_warning("renderer backend does not exist to accept resize: %i %i", width, height)
	}
}

