package core

renderer_backend_create :: proc(
	type: renderer_backend_type,
	out_renderer_backend: ^renderer_backend,
) -> bool {
	if type == .RENDERER_BACKEND_TYPE_VULKAN {
		out_renderer_backend.initialize = vulkan_renderer_backend_initialize
		out_renderer_backend.shutdown = vulkan_renderer_backend_shutdown
		out_renderer_backend.begin_frame = vulkan_renderer_backend_begin_frame
		out_renderer_backend.end_frame = vulkan_renderer_backend_end_frame
		out_renderer_backend.resized = vulkan_renderer_backend_on_resized

		return true
	}

	return false
}

renderer_backend_destroy :: proc(r_back: ^renderer_backend) {
	r_back.initialize = nil
	r_back.shutdown = nil
	r_back.begin_frame = nil
	r_back.end_frame = nil
	r_back.resized = nil
}

