package vulkan_renderer

import rv "../../renderer"

renderer_backend_create :: proc(
	type: rv.renderer_backend_type,
	out_renderer_backend: ^rv.renderer_backend,
) -> bool {
	if type == .RENDERER_BACKEND_TYPE_VULKAN {
		out_renderer_backend.initialize = vulkan_renderer_backend_initialize
		out_renderer_backend.shutdown = vulkan_renderer_backend_shutdown
		out_renderer_backend.begin_frame = vulkan_renderer_backend_begin_frame
		out_renderer_backend.end_frame = vulkan_renderer_backend_end_frame
		out_renderer_backend.resized = vulkan_renderer_backend_on_resized
		out_renderer_backend.begin_renderpass = vulkan_renderer_begin_renderpass
		out_renderer_backend.end_renderpass = vulkan_renderer_end_renderpass
		out_renderer_backend.update_global_world_state = vulkan_renderer_update_global_world_state
		out_renderer_backend.update_global_ui_state = vulkan_renderer_update_global_ui_state
		out_renderer_backend.draw_geometry = vulkan_renderer_draw_geometry
		out_renderer_backend.create_texture = vulkan_renderer_create_texture
		out_renderer_backend.destroy_texture = vulkan_renderer_destroy_texture
		out_renderer_backend.create_material = vulkan_renderer_create_material
		out_renderer_backend.destroy_material = vulkan_renderer_destroy_material
		out_renderer_backend.create_geometry = vulkan_renderer_create_geometry
		out_renderer_backend.destroy_geometry = vulkan_renderer_destroy_geometry

		return true
	}

	return false
}

renderer_backend_destroy :: proc(r_back: ^rv.renderer_backend) {
	r_back.initialize = nil
	r_back.shutdown = nil
	r_back.begin_frame = nil
	r_back.end_frame = nil
	r_back.resized = nil
	r_back.begin_renderpass = nil
	r_back.end_renderpass = nil
	r_back.update_global_world_state = nil
	r_back.update_global_ui_state = nil
	r_back.draw_geometry = nil
	r_back.create_texture = nil
	r_back.destroy_texture = nil
	r_back.create_material = nil
	r_back.destroy_material = nil
	r_back.create_geometry = nil
	r_back.destroy_geometry = nil
}
