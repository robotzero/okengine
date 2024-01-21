package core

import vk "vendor:vulkan"


vulkan_command_buffer_state :: enum {
	COMMAND_BUFFER_STATE_READY,
	COMMAND_BUFFER_STATE_RECORDING,
	COMMAND_BUFFER_STATE_IN_RENDER_PASS,
	COMMAND_BUFFER_STATE_RECORDING_ENDED,
	COMMAND_BUFFER_STATE_SUBMITTED,
	COMMAND_BUFFER_STATE_NOT_ALLOCATED,
}

vulkan_render_pass_state :: enum {
	READY,
	RECORDING,
	IN_RENDER_PASS,
	RECORDING_ENDED,
	SUBMITTED,
	NOT_ALLOCATED,
}

// @TODO when next to the variable definition?
when ODIN_DEBUG == true {
	vulkan_context :: struct {
		instance: vk.Instance,
		allocator: ^vk.AllocationCallbacks,
		debug_messenger: vk.DebugUtilsMessengerEXT,
		surface: vk.SurfaceKHR,
		device: vulkan_device,

		// The framebuffer's current width.
		framebuffer_width: u32,

		// The framebuffer's current height.
		framebuffer_height: u32,

		swapchain: vulkan_swapchain,
		main_renderpass: vulkan_renderpass,
		image_index: u32,
		current_frame: u32,
		recreating_swapchain: bool,
		find_memory_index_proc: find_memory_index,
	}
} else {
	vulkan_context :: struct {
		instance: vk.Instance,
		allocator: ^vk.AllocationCallbacks,
		surface: vk.SurfaceKHR,
		device: vulkan_device,

		// The framebuffer's current width.
		framebuffer_width: u32,

		// The framebuffer's current height.
		framebuffer_height: u32,

		swapchain: vulkan_swapchain,
		main_renderpass: vulkan_renderpass,
		image_index: u32,
		current_frame: u32,
		recreating_swapchain: boo,
		find_memory_index_proc: find_memory_index,
	}
}

vulkan_image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view: vk.ImageView,
	width: u32,
	height: u32,
}

vulkan_swapchain :: struct {
	image_format: vk.SurfaceFormatKHR,
	max_frames_in_flight: u8,
	handle: vk.SwapchainKHR,
	image_count: u32,
	images: [dynamic]vk.Image,
	views: [dynamic]vk.ImageView,

	depth_attachment: vulkan_image,
}

vulkan_command_buffer :: struct {
	handle: vk.CommandBuffer,
	state: vulkan_command_buffer_state,
}

vulkan_renderpass :: struct {
	handle: vk.RenderPass,
	x, y, w, h: f32,
	r, g, b, a: f32,

	depth: f32,
	stencil: u32,
}
