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

		// Current generation of framebuffer size. If it does not match framebuffer_size_last_generation,
    	// a new one should be generated.
    	framebuffer_size_generation: u64,

    	// The generation of the framebuffer when it was last created. Set to framebuffer_size_generation
    	// when updated.
    	framebuffer_size_last_generation: u64,

		swapchain: vulkan_swapchain,
		main_renderpass: vulkan_renderpass,

		graphics_command_buffers: [dynamic]vulkan_command_buffer,
		image_available_semaphores: [dynamic]vk.Semaphore,
		queue_complete_semaphores: [dynamic]vk.Semaphore,

		in_flight_fence_count: u32,
		in_flight_fences: [dynamic]vulkan_fence,

		// Holds pointers to fences which exist and are owned elsewere
		images_in_flight: [dynamic]^vulkan_fence,

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

		// Current generation of framebuffer size. If it does not match framebuffer_size_last_generation,
    	// a new one should be generated.
    	framebuffer_size_generation: u64,

    	// The generation of the framebuffer when it was last created. Set to framebuffer_size_generation
    	// when updated.
    	framebuffer_size_last_generation: u64,

		swapchain: vulkan_swapchain,
		main_renderpass: vulkan_renderpass,

		graphics_command_buffers: [dynamic]vulkan_command_buffer,

		image_available_semaphores: [dynamic]vk.Semaphore,
		queue_complete_semaphores: [dynamic]vk.Semaphore,

		in_flight_fence_count: u32,
		in_flight_fences: [dynamic]vulkan_fence,

		// Holds pointers to fences which exist and are owned elsewere
		images_in_flight: [dynamic]^vulkan_fence,

		image_index: u32,
		current_frame: u32,
		recreating_swapchain: bool,
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
	images: []vk.Image,
	views: []vk.ImageView,

	depth_attachment: vulkan_image,

	// framebuffers used for on-screen rendering.
	framebuffers: [dynamic]vulkan_framebuffer,
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

vulkan_framebuffer :: struct {
	handle: vk.Framebuffer,
	attachment_count: u32,
	attachments: [dynamic]vk.ImageView,
	renderpass: ^vulkan_renderpass,
}

vulkan_fence :: struct {
	handle: vk.Fence,
	is_signaled: bool,
}
