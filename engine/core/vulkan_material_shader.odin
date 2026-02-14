package core

import "../okmath"
import vk "vendor:vulkan"

BUILDIN_SHADER_NAME_MATERIAL :: "Builtin.MaterialShader"
@(private = "file")
object_shader_accumulator: f32 = 0.0

vulkan_material_shader_create :: proc(
	v_context: ^vulkan_context,
	out_shader: ^vulkan_material_shader,
) -> bool {
	// Shader module init per stage.
	stage_type_strs: [MATERIAL_SHADER_STAGE_COUNT]string = {"vert", "frag"}
	stage_types: [MATERIAL_SHADER_STAGE_COUNT]vk.ShaderStageFlags = {{.VERTEX}, {.FRAGMENT}}

	for i in 0 ..< MATERIAL_SHADER_STAGE_COUNT {
		if !create_shader_module(
			v_context,
			BUILDIN_SHADER_NAME_MATERIAL,
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
		stageFlags         = {.VERTEX},
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

	// Local/Object Descriptors
	descriptor_types: [VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT]vk.DescriptorType = {
		.UNIFORM_BUFFER, // Binding 0 - uniform buffer
		.COMBINED_IMAGE_SAMPLER, // Binding 1 - Diffuse sampler layout.
	}
	bindings: [VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT]vk.DescriptorSetLayoutBinding
	kzero_memory(
		&bindings[0],
		size_of(vk.DescriptorSetLayoutBinding) * VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT,
	)
	for i: u32 = 0; i < VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT; i += 1 {
		bindings[i].binding = i
		bindings[i].descriptorCount = 1
		bindings[i].descriptorType = descriptor_types[i]
		bindings[i].stageFlags = {.FRAGMENT}
	}

	layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT,
		pBindings    = &bindings[0],
	}
	if vk.CreateDescriptorSetLayout(
		   v_context.device.logical_device,
		   &layout_info,
		   nil,
		   &out_shader.object_descriptor_set_layout,
	   ) !=
	   vk.Result.SUCCESS {
		return false
	}

	// Local/Object descriptor pool: Used for object-specific items like diffuse colour
	object_pool_sizes: [2]vk.DescriptorPoolSize
	// The first section will be used for uniform buffers
	object_pool_sizes[0].type = .UNIFORM_BUFFER
	object_pool_sizes[0].descriptorCount = VULKAN_MAX_MATERIAL_COUNT
	// The second section will be used for image samplers.
	object_pool_sizes[1].type = .COMBINED_IMAGE_SAMPLER
	object_pool_sizes[1].descriptorCount =
		VULKAN_MATERIAL_SHADER_SAMPLER_COUNT * VULKAN_MAX_MATERIAL_COUNT

	object_pool_info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = 2,
		pPoolSizes    = &object_pool_sizes[0],
		maxSets       = VULKAN_MATERIAL_MAX_OBJECT_COUNT,
		flags         = {.FREE_DESCRIPTOR_SET},
	}

	// Create object descriptor pool.
	if vk.CreateDescriptorPool(
		   v_context.device.logical_device,
		   &object_pool_info,
		   v_context.allocator,
		   &out_shader.object_descriptor_pool,
	   ) !=
	   vk.Result.SUCCESS {
		return false
	}

	image_count := int(v_context.swapchain.image_count)
	out_shader.global_descriptor_sets = make([]vk.DescriptorSet, image_count)

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
	ATTRIBUTE_COUNT :: 2
	attribute_descriptions: [ATTRIBUTE_COUNT]vk.VertexInputAttributeDescription

	formats: [ATTRIBUTE_COUNT]vk.Format = {vk.Format.R32G32B32A32_SFLOAT, vk.Format.R32G32_SFLOAT}
	sizes: [ATTRIBUTE_COUNT]u32 = {size_of(okmath.vec3), size_of(okmath.vec2)}

	for i in 0 ..< ATTRIBUTE_COUNT {
		attribute_descriptions[i].binding = 0
		attribute_descriptions[i].location = cast(u32)i
		attribute_descriptions[i].format = formats[i]
		attribute_descriptions[i].offset = offset
		offset = offset + sizes[i]
	}

	descriptor_set_layout_count: i32 : 2
	layouts: [descriptor_set_layout_count]vk.DescriptorSetLayout = {
		out_shader.global_descriptor_set_layout,
		out_shader.object_descriptor_set_layout,
	}

	// Stages
	// NOTE: Should match the number of shader->stages
	stage_create_infos: [MATERIAL_SHADER_STAGE_COUNT]vk.PipelineShaderStageCreateInfo
	for i in 0 ..< MATERIAL_SHADER_STAGE_COUNT {
		stage_create_infos[i].sType = out_shader.stages[i].shader_stage_create_info.sType
		stage_create_infos[i] = out_shader.stages[i].shader_stage_create_info
	}

	if !vulkan_graphics_pipeline_create(
		v_context,
		&v_context.main_renderpass,
		ATTRIBUTE_COUNT,
		attribute_descriptions[:],
		cast(u32)descriptor_set_layout_count,
		&layouts[0],
		MATERIAL_SHADER_STAGE_COUNT,
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
		{.TRANSFER_DST, .UNIFORM_BUFFER},
		{.DEVICE_LOCAL, .HOST_VISIBLE, .HOST_COHERENT},
		true,
		&out_shader.global_uniform_buffer,
	) {
		log_error("Vulkan buffer creation failed for object shader.")
		return false
	}

	// Allocate global descriptor sets.
	global_layouts := make([]vk.DescriptorSetLayout, image_count)
	defer delete(global_layouts)
	for i in 0 ..< image_count {
		global_layouts[i] = out_shader.global_descriptor_set_layout
	}

	alloc_info := vk.DescriptorSetAllocateInfo {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = out_shader.global_descriptor_pool,
		descriptorSetCount = u32(image_count),
		pSetLayouts        = &global_layouts[0],
	}
	vk.AllocateDescriptorSets(
		v_context.device.logical_device,
		&alloc_info,
		&out_shader.global_descriptor_sets[0],
	)

	if !vulkan_buffer_create(
		v_context,
		size_of(material_uniform_object) * VULKAN_MAX_MATERIAL_COUNT,
		{.TRANSFER_DST, .UNIFORM_BUFFER},
		{.HOST_VISIBLE, .HOST_COHERENT},
		true,
		&out_shader.object_uniform_buffer,
	) {
		log_error("Material instance buffer creation failed for shader.")
		return false
	}
	return true
}

vulkan_material_shader_destroy :: proc(
	v_context: ^vulkan_context,
	shader: ^vulkan_material_shader,
) {
	logical_device := v_context.device.logical_device

	vk.DestroyDescriptorPool(logical_device, shader.object_descriptor_pool, v_context.allocator)
	vk.DestroyDescriptorSetLayout(
		logical_device,
		shader.object_descriptor_set_layout,
		v_context.allocator,
	)
	// Destroy uniform buffer
	vulkan_buffer_destroy(v_context, &shader.global_uniform_buffer)
	vulkan_buffer_destroy(v_context, &shader.object_uniform_buffer)

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
	for i in 0 ..< MATERIAL_SHADER_STAGE_COUNT {
		vk.DestroyShaderModule(
			v_context.device.logical_device,
			shader.stages[i].handle,
			v_context.allocator,
		)
		shader.stages[i].handle = 0
	}

	delete(shader.global_descriptor_sets)
	shader.global_descriptor_sets = nil
}

vulkan_material_shader_use :: proc(v_context: ^vulkan_context, shader: ^vulkan_material_shader) {
	image_index := int(v_context.image_index)

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
		nil,
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

vulkan_material_shader_update_object :: proc(
	v_context: ^vulkan_context,
	shader: ^vulkan_material_shader,
	data: geometry_render_data,
) {
	image_index := int(v_context.image_index)
	command_buffer := v_context.graphics_command_buffers[image_index].handle
	local_model := data.model
	vk.CmdPushConstants(
		command_buffer,
		shader.pipeline.pipeline_layout,
		{.VERTEX},
		0,
		size_of(okmath.mat4),
		&local_model,
	)

	// Obtain material data.
	object_state := &shader.instance_states[cast(int)data.material.internal_id]
	object_descriptor_set := object_state.descriptor_sets[image_index]

	// TODO: if needs update
	descriptor_writes: [VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT]vk.WriteDescriptorSet
	kzero_memory(
		&descriptor_writes[0],
		size_of(vk.WriteDescriptorSet) * VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT,
	)
	descriptor_count: u32 = 0
	descriptor_index: u32 = 0

	// Descriptor 0 - Uniform buffer
	range: u64 = u64(size_of(material_uniform_object))
	offset: u64 = range * u64(data.material.internal_id) // also the index into the array.
	obo: material_uniform_object

	// TODO: get diffuse colour from a material.
	// object_shader_accumulator += v_context.frame_delta_time
	// s := (okmath.ksin(object_shader_accumulator) + 1.0) / 2.0 // scale from -1, 1 to 0, 1
	// obo.diffuse_color = okmath.vec4_create(s, s, s, 1.0)
	obo.diffuse_color = data.material.diffuse_colour

	// Load the data into the buffer.
	vulkan_buffer_load_data(v_context, &shader.object_uniform_buffer, offset, range, {}, &obo)
	global_ubo_generation := &object_state.descriptor_states[descriptor_index].generations[image_index]
	if global_ubo_generation^ == INVALID_ID || global_ubo_generation^ != data.material.generation {
		buffer_info := vk.DescriptorBufferInfo {
			buffer = shader.object_uniform_buffer.handle,
			offset = vk.DeviceSize(offset),
			range  = vk.DeviceSize(range),
		}

		descriptor := vk.WriteDescriptorSet {
			sType           = .WRITE_DESCRIPTOR_SET,
			dstSet          = object_descriptor_set,
			dstBinding      = descriptor_index,
			descriptorType  = .UNIFORM_BUFFER,
			descriptorCount = 1,
			pBufferInfo     = &buffer_info,
		}

		descriptor_writes[descriptor_count] = descriptor
		descriptor_count += 1

		// Update the frame generation. In this case it is only needed once since this is a buffer.
		global_ubo_generation^ = data.material.generation
	}
	descriptor_index += 1

	// samplers.
	sampler_count: u32 = 1
	image_infos: [1]vk.DescriptorImageInfo
	for sampler_index: u32 = 0; sampler_index < sampler_count; sampler_index += 1 {
		use := shader.sampler_uses[sampler_index]
		t: ^texture
		#partial switch (use) {
		case texture_use.TEXTURE_USE_MAP_DIFFUSE:
			t = data.material.diffuse_map.texture
		case:
			log_fatal("Unable to bind sampler to unknown use.")
			return
		}
		descriptor_generation := &object_state.descriptor_states[descriptor_index].generations[image_index]
		descriptor_id := &object_state.descriptor_states[descriptor_index].ids[image_index]

		if t.generation == INVALID_ID {
			t = texture_system_get_default_texture()
			descriptor_generation^ = INVALID_ID

		}
		// Check if the descriptor needs updating first.
		if t != nil &&
		   (descriptor_id^ != t.id ||
				   descriptor_generation^ != t.generation ||
				   descriptor_generation^ == INVALID_ID) {
			internal_data := cast(^vulkan_texture_data)t.internal_data

			// Assign view and sampler.
			image_infos[sampler_index].imageLayout = .SHADER_READ_ONLY_OPTIMAL
			image_infos[sampler_index].imageView = internal_data.image.view
			image_infos[sampler_index].sampler = internal_data.sampler

			descriptor := vk.WriteDescriptorSet {
				sType           = .WRITE_DESCRIPTOR_SET,
				dstSet          = object_descriptor_set,
				dstBinding      = descriptor_index,
				descriptorType  = .COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				pImageInfo      = &image_infos[sampler_index],
			}

			descriptor_writes[descriptor_count] = descriptor
			descriptor_count += 1

			// Sync frame generation if not using a default texture.
			if t.generation != INVALID_ID {
				descriptor_generation^ = t.generation
				descriptor_id^ = t.id
			}
			descriptor_index += 1
		}
	}
	if descriptor_count > 0 {
		vk.UpdateDescriptorSets(
			v_context.device.logical_device,
			descriptor_count,
			&descriptor_writes[0],
			0,
			nil,
		)
	}

	// Bind the descriptor set to be updated, or in case the shader changed.
	vk.CmdBindDescriptorSets(
		command_buffer,
		vk.PipelineBindPoint.GRAPHICS,
		shader.pipeline.pipeline_layout,
		1,
		1,
		&object_descriptor_set,
		0,
		nil,
	)
}

vulkan_material_shader_update_global_state :: proc(
	v_context: ^vulkan_context,
	shader: ^vulkan_material_shader,
	delta_time: f32,
) {
	image_index := int(v_context.image_index)
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
	vulkan_buffer_load_data(
		v_context,
		&shader.global_uniform_buffer,
		u64(offset),
		u64(range),
		nil,
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
vulkan_material_shader_acquire_resources :: proc(
	v_context: ^vulkan_context,
	shader: ^vulkan_material_shader,
	material: ^material,
	allocator := context.allocator,
) -> b8 {
	// TODO: free list
	material.internal_id = shader.object_uniform_buffer_index
	shader.object_uniform_buffer_index += 1

	image_count := int(v_context.swapchain.image_count)
	object_state := &shader.instance_states[material.internal_id]
	object_state.descriptor_sets = make([]vk.DescriptorSet, image_count, allocator)
	for i: u32 = 0; i < VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT; i += 1 {
		//@MEMORY use containers with tagged memory
		object_state.descriptor_states[i].generations = make([]u32, image_count, allocator)
		object_state.descriptor_states[i].ids = make([]u32, image_count, allocator)
		for j: int = 0; j < image_count; j += 1 {
			object_state.descriptor_states[i].generations[j] = INVALID_ID
			object_state.descriptor_states[i].ids[j] = INVALID_ID
		}
	}

	// Allocate descriptor sets.
	layouts := make([]vk.DescriptorSetLayout, image_count)
	defer delete(layouts)
	for i: int = 0; i < image_count; i += 1 {
		layouts[i] = shader.object_descriptor_set_layout
	}

	alloc_info := vk.DescriptorSetAllocateInfo {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = shader.object_descriptor_pool,
		descriptorSetCount = u32(image_count), // one per swapchain image
		pSetLayouts        = &layouts[0],
	}
	result := vk.AllocateDescriptorSets(
		v_context.device.logical_device,
		&alloc_info,
		&object_state.descriptor_sets[0],
	)
	if result != vk.Result.SUCCESS {
		log_error("Error allocating descriptor sets in shader!")
		return false
	}

	return true
}

vulkan_material_shader_release_resources :: proc(
	v_context: ^vulkan_context,
	shader: ^vulkan_material_shader,
	material: ^material,
) {
	instance_state := &shader.instance_states[material.internal_id]

	image_count := u32(v_context.swapchain.image_count)
	// Release object descriptor sets.
	result := vk.FreeDescriptorSets(
		v_context.device.logical_device,
		shader.object_descriptor_pool,
		image_count,
		&instance_state.descriptor_sets[0],
	)
	if result != vk.Result.SUCCESS {
		log_error("Error freeing object shader descriptor sets!")
	}

	for i: u32 = 0; i < VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT; i += 1 {
		for j: u32 = 0; j < 3; j += 1 {
			instance_state.descriptor_states[i].generations[j] = INVALID_ID
			instance_state.descriptor_states[i].ids[j] = INVALID_ID
		}
		// delete(object_state.descriptor_states[i].generations)
		// object_state.descriptor_states[i].generations = nil
	}
	material.internal_id = INVALID_ID
	// delete(object_state.descriptor_sets)
	// object_state.descriptor_sets = nil
}

