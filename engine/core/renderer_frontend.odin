package core

static_mesh_data :: struct {}

// Backend renderer context
backend : ^renderer_backend = nil

renderer_initialize :: proc(application_name: string, plat_state: ^platform_state) -> bool {
	backend = kallocate(size_of(renderer_backend), .MEMORY_TAG_RENDERER, renderer_backend)

	// @TODO: make this configurable
	renderer_backend_create(.RENDERER_BACKEND_TYPE_VULKAN, plat_state, backend)
	backend.frame_number = 0

	if !backend.initialize(backend, application_name, plat_state) {
		log_fatal("Renderer backend failed to initialize. Shuttind down")
		return false
	}

	return true
}


renderer_shutdown :: proc () {
	backend.shutdown(backend)
	kfree(backend, size_of(renderer_backend), .MEMORY_TAG_RENDERER)
}

renderer_begin_frame :: proc(delta_time: f32) -> bool {
	return backend.begin_frame(backend, delta_time)
}

renderer_end_frame :: proc(delta_time: f32) -> bool {
	result : bool = backend.end_frame(backend, delta_time)
	backend.frame_number = backend.frame_number + 1
	return result
}

renderer_draw_frame :: proc(packet: ^render_packet) -> bool {
	// If the begin frame returned successfully, mid-frame operation may continue.
	if renderer_begin_frame(packet.delta_time) {
		// End the frame. If this fails, it is likely unrecoverable.
		result : bool = renderer_end_frame(packet.delta_time)

		if !result {
			log_error("renderer_end_frame failed. Application shutting down...")
			return false
		}
	}

	return true
}
