package core

import "../okmath"
import vk "vendor:vulkan"

BUILDIN_SHADER_NAME_OBJECT :: "Builtin.ObjectShader"

vulkan_object_shader_create :: proc(
	v_context: ^vulkan_context,
	out_shader: ^vulkan_object_shader,
) -> bool {

	// Shader module init per stage.
	stage_type_strs: [OBJECT_SHADER_STAGE_COUNT]string = {"vert", "frag"}
	stage_types: [OBJECT_SHADER_STAGE_COUNT]vk.ShaderStageFlags = {{.VERTEX}, {.FRAGMENT}}

	for i in 0 ..< OBJECT_SHADER_STAGE_COUNT {
		if !create_shader_module(
			v_context,
			BUILDIN_SHADER_NAME_OBJECT,
			stage_type_strs[i],
			stage_types[i],
			cast(u32)i,
			&out_shader.stages,
		) {
			return false
		}
	}

	// Descriptors
	global_ubo_layout_binding := vk.DescriptorSetLayoutBinding {
		binding            = 0,
		descriptorCount    = 1,
		descriptorType     = .UNIFORM_BUFFER,
		pImmutableSamplers = nil,
		stageFlags         = .VERTEX_BIT,
	}

	global_layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = 1,
		pBindings    = &global_ubo_layout_binding,
	}

	// Create descriptor set layout
	res := vk.CreateDescriptorSetLayout(
		v_context.device.logical_device,
		&global_layout_info,
		v_context.allocator,
		&out_shader.global_descriptor_set_layout,
	)
	if res != vk.Result.SUCCESS {
		return false
	}

	// Global descriptor pool size (one UBO per swapchain image)
	global_pool_size := vk.DescriptorPoolSize {
		type            = .UNIFORM_BUFFER,
		descriptorCount = v_context.swapchain.image_count,
	}

	global_pool_info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = 1,
		pPoolSizes    = &global_pool_size,
		maxSets       = v_context.swapchain.image_count,
	}

	// Create descriptor pool
	res = vk.CreateDescriptorPool(
		v_context.device.logical_device,
		&global_pool_info,
		v_context.allocator,
		&out_shader.global_descriptor_pool,
	)
	if res != vk.Result.SUCCESS {
		return false
	}

	viewport: vk.Viewport
	viewport.x = 0.0
	viewport.y = cast(f32)v_context.framebuffer_height
	viewport.width = cast(f32)v_context.framebuffer_width
	viewport.height = -cast(f32)v_context.framebuffer_height
	viewport.minDepth = 0.0
	viewport.maxDepth = 1.0

	// Scissor
	scissor: vk.Rect2D
	scissor.offset.x = 0
	scissor.offset.y = 0
	scissor.extent.width = v_context.framebuffer_width
	scissor.extent.height = v_context.framebuffer_height

	// Attributes
	offset: u32 = 0
	attribute_count :: 1
	attribute_descriptions: [attribute_count]vk.VertexInputAttributeDescription

	formats: [attribute_count]vk.Format = {vk.Format.R32G32B32A32_SFLOAT}
	sizes: [attribute_count]u32 = {size_of(okmath.vec3)}

	for i in 0 ..< attribute_count {
		attribute_descriptions[i].binding = 0
		attribute_descriptions[i].location = cast(u32)i
		attribute_descriptions[i].format = formats[i]
		attribute_descriptions[i].offset = offset
		offset = offset + sizes[i]
	}

	descriptor_set_layout_count: i32 : 1
	layouts: [descriptor_set_layout_count]vk.DescriptorSetLayout = {
		out_shader.global_descriptor_set_layout,
	}

	// Stages
	// NOTE: Should match the number of shader->stages
	stage_create_infos: [OBJECT_SHADER_STAGE_COUNT]vk.PipelineShaderStageCreateInfo
	for i in 0 ..< OBJECT_SHADER_STAGE_COUNT {
		stage_create_infos[i].sType = out_shader.stages[i].shader_stage_create_info.sType
		stage_create_infos[i] = out_shader.stages[i].shader_stage_create_info
	}

	if !vulkan_graphics_pipeline_create(
		v_context,
		&v_context.main_renderpass,
		attribute_count,
		attribute_descriptions[:],
		descriptor_set_layout_count,
		layouts[:],
		OBJECT_SHADER_STAGE_COUNT,
		stage_create_infos[:],
		&viewport,
		&scissor,
		false,
		&out_shader.pipeline,
	) {
		log_error("Failed to load graphics pipeline for object shader.")
		return false
	}

	if !vulkan_buffer_create(
		v_context,
		size_of(global_uniform_object),
		{
			.TRANSFER_DST,
			.UNIFORM_BUFFER,
			vk.MemoryPropertyFlag.DEVICE_LOCAL,
			vk.MemoryPropertyFlag.HOST_VISIBLE,
			vk.MemoryPropertyFlag.HOST_COHERENT,
		},
		true,
		&out_shader.global_uniform_buffer,
	) {
		log_error("Vulkan buffer creation failed for object shader.")
		return false
	}

	alloc_info := vk.DescriptorSetAllocateInfo {
		sType              = .ALLOCATE_INFO,
		descriptorPool     = out_shader.global_descriptor_pool,
		descriptorSetCount = 3,
		pSetLayouts        = global_layouts,
	}
	vk.AllocateDescriptorSets(
		v_context.device.logical_device,
		&alloc_info,
		out_shader.global_descriptor_sets,
	)
	return true
}

vulkan_object_shader_destroy :: proc(v_context: ^vulkan_context, shader: ^vulkan_object_shader) {
	logical_device := v_context.device.logical_device

	// Destroy uniform buffer
	vulkan_buffer_destroy(v_context, &shader.global_uniform_buffer)

	// Destroy pipeline
	vulkan_pipeline_destroy(v_context, &shader.pipeline)

	// Destroy global descriptor pool
	vk.DestroyDescriptorPool(logical_device, shader.global_descriptor_pool, v_context.allocator)

	// Destroy set layouts
	vk.DestroyDescriptorSetLayout(
		logical_device,
		shader.global_descriptor_set_layout,
		v_context.allocator,
	)
	for i in 0 ..< OBJECT_SHADER_STAGE_COUNT {
		vk.DestroyShaderModule(
			v_context.device.logical_device,
			shader.stages[i].handle,
			v_context.allocator,
		)
		shader.stages[i].handle = 0
	}
}

vulkan_object_shader_use :: proc(v_context: ^vulkan_context, shader: ^vulkan_object_shader) {
	image_index := v_context.image_index

	vulkan_pipeline_bind(
		&v_context.graphics_command_buffers[image_index],
		vk.PipelineBindPoint.GRAPHICS,
		&shader.pipeline,
	)

	command_buffer := v_context.graphics_command_buffers[image_index].handle
	global_descriptor := shader.global_descriptor_sets[image_index]

	// Bind the global descriptor set to be updated.
	vk.CmdBindDescriptorSets(
		command_buffer,
		vk.PipelineBindPoint.GRAPHICS,
		shader.pipeline.pipeline_layout,
		0,
		1,
		&global_descriptor,
		0,
		nil,
	)

	// Configure the descriptors for the given index.
	range: vk.DeviceSize = vk.DeviceSize(size_of(global_uniform_object))
	offset: vk.DeviceSize = 0

	// Copy data to buffer.
	// If your vulkan_buffer_load_data takes u64, keep u64 and cast as needed.
	vulkan_buffer_load_data(
		v_context,
		&shader.global_uniform_buffer,
		u64(offset),
		u64(range),
		0,
		&shader.global_ubo,
	)

	buffer_info := vk.DescriptorBufferInfo {
		buffer = shader.global_uniform_buffer.handle,
		offset = offset,
		range  = range,
	}

	// Update descriptor sets.
	descriptor_write := vk.WriteDescriptorSet {
		sType           = .WRITE_DESCRIPTOR_SET,
		dstSet          = shader.global_descriptor_sets[image_index],
		dstBinding      = 0,
		dstArrayElement = 0,
		descriptorType  = .UNIFORM_BUFFER,
		descriptorCount = 1,
		pBufferInfo     = &buffer_info,
	}

	vk.UpdateDescriptorSets(v_context.device.logical_device, 1, &descriptor_write, 0, nil)
}

vulkan_object_shader_update_object :: proc(
	v_context: ^vulkan_context,
	shader: ^vulkan_object_shader,
	model: okmath.mat4,
) {
	image_index := v_context.image_index
	command_buffer := v_context.graphics_command_buffers[image_index].handle
	vk.CmdPushConstants(
		command_buffer,
		shader.pipeline.pipeline_layout,
		vk.ShaderStageFlag.VERTEX,
		0,
		size_of(okmath.mat4),
		&model,
	)
}

