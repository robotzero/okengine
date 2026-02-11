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
		out_renderer_backend.update_global_state = vulkan_renderer_update_global_state
		out_renderer_backend.update_object = vulkan_backend_update_object
		out_renderer_backend.create_texture = vulkan_renderer_create_texture
		out_renderer_backend.destroy_texture = vulkan_renderer_destroy_texture
		out_renderer_backend.destroy_material = vulkan_renderer_destroy_material

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
	r_back.update_global_state = nil
	r_back.update_object = nil
	r_back.create_texture = nil
	r_back.destroy_texture = nil
	r_back.destroy_material = nil
}

