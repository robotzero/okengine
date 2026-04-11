package vulkan_renderer

import c "../../containers"
import "../../okmath"
import rv "../../renderer"
import res "../../resources"
import vk "vendor:vulkan"

MATERIAL_SHADER_STAGE_COUNT :: 2
VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT :: 2
VULKAN_MATERIAL_MAX_OBJECT_COUNT :: 1024
VULKAN_MATERIAL_SHADER_SAMPLER_COUNT :: 1
VULKAN_MAX_MATERIAL_COUNT :: 1024
VULKAN_MAX_GEOMETRY_COUNT :: 4096
INVALID_ID :: res.INVALID_ID

UI_SHADER_STAGE_COUNT :: 2
VULKAN_UI_SHADER_DESCRIPTOR_COUNT :: 2
VULKAN_UI_SHADER_SAMPLER_COUNT :: 1
VULKAN_MAX_UI_COUNT :: 1024

global_uniform_object :: rv.global_uniform_object
material_uniform_object :: rv.material_uniform_object
geometry_render_data :: rv.geometry_render_data
texture_use :: res.texture_use
texture :: res.texture
material :: res.material

// Renamed UBO types for material shader (vulkan-specific)
vulkan_material_shader_global_ubo :: struct {
	projection:  okmath.mat4,
	view:        okmath.mat4,
	m_reserved0: okmath.mat4,
	m_reserved1: okmath.mat4,
}

vulkan_material_shader_instance_ubo :: struct {
	diffuse_color: okmath.vec4,
	v_reserved_0:  okmath.vec4,
	v_reserved_1:  okmath.vec4,
	v_reserved_2:  okmath.vec4,
	m_reserved0:   okmath.mat4,
	m_reserved1:   okmath.mat4,
	m_reserved2:   okmath.mat4,
}

// UI shader UBO types
vulkan_ui_shader_global_ubo :: struct {
	projection:  okmath.mat4,
	view:        okmath.mat4,
	m_reserved0: okmath.mat4,
	m_reserved1: okmath.mat4,
}

vulkan_ui_shader_instance_ubo :: struct {
	diffuse_color: okmath.vec4,
	v_reserved_0:  okmath.vec4,
	v_reserved_1:  okmath.vec4,
	v_reserved_2:  okmath.vec4,
	m_reserved0:   okmath.mat4,
	m_reserved1:   okmath.mat4,
	m_reserved2:   okmath.mat4,
}

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

when ODIN_DEBUG == true {
	vulkan_debug_messenger :: struct {
		debug_messenger: vk.DebugUtilsMessengerEXT,
	}
} else {
	vulkan_debug_messanger :: struct {
	}
}

vulkan_descriptor_state :: struct {
	// Per swapchain image.
	generations: []u32,
	ids:         []u32,
}

vulkan_material_shader_instance_state :: struct {
	// Per swapchain image
	descriptor_sets:   []vk.DescriptorSet,

	// per descriptor
	descriptor_states: [VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT]vulkan_descriptor_state,
}

vulkan_ui_shader_instance_state :: struct {
	// Per swapchain image
	descriptor_sets:   []vk.DescriptorSet,

	// per descriptor
	descriptor_states: [VULKAN_UI_SHADER_DESCRIPTOR_COUNT]vulkan_descriptor_state,
}

// renderpass_clear_flag controls which buffers are cleared and whether depth is included.
renderpass_clear_flag :: enum u8 {
	NONE    = 0x0,
	COLOUR  = 0x1,
	DEPTH   = 0x2,
	STENCIL = 0x4,
}

vulkan_context :: struct {
	instance:                         vk.Instance,
	allocator:                        ^vk.AllocationCallbacks,
	debug_messenger:                  vulkan_debug_messenger,
	surface:                          vk.SurfaceKHR,
	device:                           vulkan_device,
	frame_delta_time:                 f32,

	// The framebuffer's current width.
	framebuffer_width:                u32,

	// The framebuffer's current height.
	framebuffer_height:               u32,

	// Current generation of framebuffer size. If it does not match framebuffer_size_last_generation,
	// a new one should be generated.
	framebuffer_size_generation:      u64,

	// The generation of the framebuffer when it was last created. Set to framebuffer_size_generation
	// when updated.
	framebuffer_size_last_generation: u64,
	swapchain:                        vulkan_swapchain,
	main_renderpass:                  vulkan_renderpass,
	ui_renderpass:                    vulkan_renderpass,

	// World framebuffers (color + depth), one per swapchain image.
	world_framebuffers:               []vk.Framebuffer,
	object_vertex_buffer:             vulkan_buffer,
	object_index_buffer:              vulkan_buffer,
	graphics_command_buffers:         [dynamic]vulkan_command_buffer,
	image_available_semaphores:       [dynamic]vk.Semaphore,
	queue_complete_semaphores:        [dynamic]vk.Semaphore,

	// In-flight fences, one per frame-in-flight (raw handles).
	in_flight_fences:                 [2]vk.Fence,

	// Holds pointers to fences which exist and are owned elsewhere (nil = not in use).
	images_in_flight:                 []^vk.Fence,
	image_index:                      u32,
	current_frame:                    u32,
	recreating_swapchain:             bool,
	material_shader:                  vulkan_material_shader,
	ui_shader:                        vulkan_ui_shader,
	find_memory_index_proc:           find_memory_index,
	geometries:                       [VULKAN_MAX_GEOMETRY_COUNT]vulkan_geometry_data,
}

vulkan_geometry_data :: struct {
	id:                   u32,
	generation:           u32,
	vertex_count:         u32,
	vertex_element_size:  u64,
	vertex_buffer_offset: u64,
	index_count:          u32,
	index_element_size:   u64,
	index_buffer_offset:  u64,
}

geometry :: res.geometry

vulkan_texture_data :: struct {
	image:   vulkan_image,
	sampler: vk.Sampler,
}

vulkan_image :: struct {
	handle: vk.Image,
	memory: vk.DeviceMemory,
	view:   vk.ImageView,
	width:  u32,
	height: u32,
}

vulkan_swapchain :: struct {
	image_format:         vk.SurfaceFormatKHR,
	max_frames_in_flight: u8,
	handle:               vk.SwapchainKHR,
	image_count:          u32,
	images:               []vk.Image,
	views:                []vk.ImageView,
	depth_attachment:     vulkan_image,

	// UI framebuffers used for on-screen rendering (color only).
	framebuffers:         []vk.Framebuffer,
}

vulkan_command_buffer :: struct {
	handle: vk.CommandBuffer,
	state:  vulkan_command_buffer_state,
}

vulkan_renderpass :: struct {
	handle:        vk.RenderPass,
	render_area:   okmath.vec4, // x, y, w, h
	clear_colour:  okmath.vec4, // r, g, b, a
	depth:         f32,
	stencil:       u32,
	clear_flags:   u8,
	has_prev_pass: bool,
	has_next_pass: bool,
}

vulkan_shader_stage :: struct {
	create_info:              vk.ShaderModuleCreateInfo,
	handle:                   vk.ShaderModule,
	shader_stage_create_info: vk.PipelineShaderStageCreateInfo,
}

vulkan_pipeline :: struct {
	handle:          vk.Pipeline,
	pipeline_layout: vk.PipelineLayout,
}

vulkan_material_shader :: struct {
	pipeline:                     vulkan_pipeline,
	stages:                       [MATERIAL_SHADER_STAGE_COUNT]vulkan_shader_stage,
	global_descriptor_pool:       vk.DescriptorPool,
	global_descriptor_set_layout: vk.DescriptorSetLayout,
	// One descriptor set per swapchain image
	global_descriptor_sets:       []vk.DescriptorSet,
	global_ubo:                   vulkan_material_shader_global_ubo,
	global_uniform_buffer:        vulkan_buffer,
	object_descriptor_pool:       vk.DescriptorPool,
	object_descriptor_set_layout: vk.DescriptorSetLayout,
	object_uniform_buffer:        vulkan_buffer,
	object_uniform_buffer_index:  u32,
	sampler_uses:                 [VULKAN_MATERIAL_SHADER_SAMPLER_COUNT]texture_use,
	instance_states:              [VULKAN_MATERIAL_MAX_OBJECT_COUNT]vulkan_material_shader_instance_state,
}

vulkan_ui_shader :: struct {
	pipeline:                     vulkan_pipeline,
	stages:                       [UI_SHADER_STAGE_COUNT]vulkan_shader_stage,
	global_descriptor_pool:       vk.DescriptorPool,
	global_descriptor_set_layout: vk.DescriptorSetLayout,
	// One descriptor set per swapchain image
	global_descriptor_sets:       []vk.DescriptorSet,
	global_ubo:                   vulkan_ui_shader_global_ubo,
	global_uniform_buffer:        vulkan_buffer,
	object_descriptor_pool:       vk.DescriptorPool,
	object_descriptor_set_layout: vk.DescriptorSetLayout,
	object_uniform_buffer:        vulkan_buffer,
	object_uniform_buffer_index:  u32,
	sampler_uses:                 [VULKAN_UI_SHADER_SAMPLER_COUNT]texture_use,
	instance_states:              [VULKAN_MAX_UI_COUNT]vulkan_ui_shader_instance_state,
}

vulkan_buffer :: struct {
	total_size:            u64,
	handle:                vk.Buffer,
	usage:                 vk.BufferUsageFlags,
	is_locked:             bool,
	memory:                vk.DeviceMemory,
	memory_index:          i32,
	memory_property_flags: vk.MemoryPropertyFlags,
	buffer_freelist:       c.freelist,
}

must :: proc(result: vk.Result, loc := #caller_location) {
	if result != .SUCCESS {
		panic("AAAAAAAAAAAAAAAAAA")
	}
}

