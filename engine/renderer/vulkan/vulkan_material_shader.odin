package vulkan_renderer

import l "../../logger"
import "../../okmath"
import sys "../../systems"
import "base:runtime"
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
			u32(i),
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
	// Binding 0: uniform buffer; Binding 1: sampler array (diffuse + specular)
	bindings: [VULKAN_MATERIAL_SHADER_DESCRIPTOR_COUNT]vk.DescriptorSetLayoutBinding = {
		{
			binding         = 0,
			descriptorCount = 1,
			descriptorType  = .UNIFORM_BUFFER,
			stageFlags      = {.FRAGMENT},
		},
		{
			binding         = 1,
			descriptorCount = VULKAN_MATERIAL_SHADER_SAMPLER_COUNT, // array of samplers
			descriptorType  = .COMBINED_IMAGE_SAMPLER,
			stageFlags      = {.FRAGMENT},
		},
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
	object_pool_sizes := [2]vk.DescriptorPoolSize {
		// The first section will be used for uniform buffers
		{type = .UNIFORM_BUFFER, descriptorCount = VULKAN_MAX_MATERIAL_COUNT},
		// The second section will be used for image samplers.
		{
			type = .COMBINED_IMAGE_SAMPLER,
			descriptorCount = VULKAN_MATERIAL_SHADER_SAMPLER_COUNT * VULKAN_MAX_MATERIAL_COUNT,
		},
	}

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

	// Sampler binding 0 is the material diffuse map.
	out_shader.sampler_uses[0] = texture_use.TEXTURE_USE_MAP_DIFFUSE
	// Sampler binding 1 is the material specular map.
	out_shader.sampler_uses[1] = texture_use.TEXTURE_USE_MAP_SPECULAR

	image_count := int(v_context.swapchain.image_count)
	out_shader.global_descriptor_sets = make([]vk.DescriptorSet, image_count)

	viewport := vk.Viewport {
		x        = 0.0,
		y        = f32(v_context.framebuffer_height),
		width    = f32(v_context.framebuffer_width),
		height   = -f32(v_context.framebuffer_height),
		minDepth = 0.0,
		maxDepth = 1.0,
	}

	// Scissor
	scissor := vk.Rect2D {
		offset = {x = 0, y = 0},
		extent = {width = v_context.framebuffer_width, height = v_context.framebuffer_height},
	}

	// Attributes: position (vec3), normal (vec3), texcoord (vec2)
	offset: u32 = 0
	ATTRIBUTE_COUNT :: 3
	attribute_descriptions: [ATTRIBUTE_COUNT]vk.VertexInputAttributeDescription

	formats: [ATTRIBUTE_COUNT]vk.Format = {vk.Format.R32G32B32_SFLOAT, vk.Format.R32G32B32_SFLOAT, vk.Format.R32G32_SFLOAT}
	sizes: [ATTRIBUTE_COUNT]u32 = {size_of(okmath.vec3), size_of(okmath.vec3), size_of(okmath.vec2)}

	for i in 0 ..< ATTRIBUTE_COUNT {
		attribute_descriptions[i].binding = 0
		attribute_descriptions[i].location = u32(i)
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
		u32(descriptor_set_layout_count),
		&layouts[0],
		MATERIAL_SHADER_STAGE_COUNT,
		stage_create_infos[:],
		&viewport,
		&scissor,
		false,
		true,
		size_of(okmath.vertex_3d),
		&out_shader.pipeline,
	) {
		l.log_error("Failed to load graphics pipeline for object shader.")
		return false
	}

	if !vulkan_buffer_create(
		v_context,
		size_of(vulkan_material_shader_global_ubo),
		{.TRANSFER_DST, .UNIFORM_BUFFER},
		{.DEVICE_LOCAL, .HOST_VISIBLE, .HOST_COHERENT},
		true,
		&out_shader.global_uniform_buffer,
	) {
		l.log_error("Vulkan buffer creation failed for object shader.")
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
		size_of(vulkan_material_shader_instance_ubo) * VULKAN_MAX_MATERIAL_COUNT,
		{.TRANSFER_DST, .UNIFORM_BUFFER},
		{.HOST_VISIBLE, .HOST_COHERENT},
		true,
		&out_shader.object_uniform_buffer,
	) {
		l.log_error("Material instance buffer creation failed for shader.")
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
	range: vk.DeviceSize = vk.DeviceSize(size_of(vulkan_material_shader_global_ubo))
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

vulkan_material_shader_set_model :: proc(
	v_context: ^vulkan_context,
	shader: ^vulkan_material_shader,
	model: okmath.mat4,
) {
	if v_context != nil && shader != nil {
		image_index := int(v_context.image_index)
		command_buffer := v_context.graphics_command_buffers[image_index].handle
		local_model := model
		vk.CmdPushConstants(
			command_buffer,
			shader.pipeline.pipeline_layout,
			{.VERTEX},
			0,
			size_of(okmath.mat4),
			&local_model,
		)
	}
}

vulkan_material_shader_apply_material :: proc(
	v_context: ^vulkan_context,
	shader: ^vulkan_material_shader,
	mat: ^material,
) {
	if v_context == nil || shader == nil {
		return
	}
	image_index := int(v_context.image_index)
	command_buffer := v_context.graphics_command_buffers[image_index].handle

	// Obtain material data.
	object_state := &shader.instance_states[int(mat.internal_id)]
	object_descriptor_set := object_state.descriptor_sets[image_index]

	// TODO: if needs update
	descriptor_writes: [VULKAN_MATERIAL_SHADER_INSTANCE_DESCRIPTOR_COUNT]vk.WriteDescriptorSet
	descriptor_count: u32 = 0
	descriptor_index: u32 = 0

	// Descriptor 0 - Uniform buffer
	range: u64 = u64(size_of(vulkan_material_shader_instance_ubo))
	offset: u64 = range * u64(mat.internal_id) // also the index into the array.
	obo: vulkan_material_shader_instance_ubo

	obo.diffuse_color = mat.diffuse_colour
	obo.shininess = mat.shininess

	// Load the data into the buffer.
	vulkan_buffer_load_data(v_context, &shader.object_uniform_buffer, offset, range, {}, &obo)
	global_ubo_generation := &object_state.descriptor_states[descriptor_index].generations[image_index]
	if global_ubo_generation^ == INVALID_ID || global_ubo_generation^ != mat.generation {
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
		global_ubo_generation^ = mat.generation
	}
	descriptor_index += 1

	// samplers — all share binding 1 as an array, indexed by sampler_index (dstArrayElement).
	sampler_count: u32 = VULKAN_MATERIAL_SHADER_SAMPLER_COUNT
	image_infos: [VULKAN_MATERIAL_SHADER_SAMPLER_COUNT]vk.DescriptorImageInfo
	for sampler_index in 0 ..< sampler_count {
		use := shader.sampler_uses[sampler_index]
		t: ^texture
		#partial switch (use) {
		case texture_use.TEXTURE_USE_MAP_DIFFUSE:
			t = mat.diffuse_map.texture
		case texture_use.TEXTURE_USE_MAP_SPECULAR:
			t = mat.specular_map.texture
		case:
			l.log_fatal("Unable to bind sampler to unknown use.")
			return
		}
		// descriptor_states[descriptor_index] tracks the binding slot (always 1 for samplers);
		// we use sampler_index as a sub-index within that binding's per-sampler generation tracking.
		descriptor_generation := &object_state.descriptor_states[descriptor_index].generations[image_index]
		descriptor_id := &object_state.descriptor_states[descriptor_index].ids[image_index]

		if t.generation == INVALID_ID {
			t = sys.texture_system_get_default_texture()
			descriptor_generation^ = INVALID_ID
		}
		// Check if the descriptor needs updating first.
		if t != nil &&
		   (descriptor_id^ != t.id ||
				   descriptor_generation^ != t.generation ||
				   descriptor_generation^ == INVALID_ID) {
			internal_data := (^vulkan_texture_data)(t.internal_data)

			// Assign view and sampler.
			image_infos[sampler_index].imageLayout = .SHADER_READ_ONLY_OPTIMAL
			image_infos[sampler_index].imageView = internal_data.image.view
			image_infos[sampler_index].sampler = internal_data.sampler

			// All samplers write to binding 1; dstArrayElement selects the array slot.
			descriptor := vk.WriteDescriptorSet {
				sType            = .WRITE_DESCRIPTOR_SET,
				dstSet           = object_descriptor_set,
				dstBinding       = 1,
				dstArrayElement  = u32(sampler_index),
				descriptorType   = .COMBINED_IMAGE_SAMPLER,
				descriptorCount  = 1,
				pImageInfo       = &image_infos[sampler_index],
			}

			descriptor_writes[descriptor_count] = descriptor
			descriptor_count += 1

			// Sync frame generation if not using a default texture.
			if t.generation != INVALID_ID {
				descriptor_generation^ = t.generation
				descriptor_id^ = t.id
			}
		}
		descriptor_index += 1
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

	// Configure the descriptors for the given index.
	range: vk.DeviceSize = vk.DeviceSize(size_of(vulkan_material_shader_global_ubo))
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

	//@TODO sort out memory
	material_alloc := runtime.default_context().allocator
	image_count := int(v_context.swapchain.image_count)
	object_state := &shader.instance_states[material.internal_id]
	object_state.descriptor_sets = make([]vk.DescriptorSet, image_count, material_alloc)
	for i in 0 ..< u32(VULKAN_MATERIAL_SHADER_INSTANCE_DESCRIPTOR_COUNT) {
		//@MEMORY use containers with tagged memory
		object_state.descriptor_states[i].generations = make([]u32, image_count, material_alloc)
		object_state.descriptor_states[i].ids = make([]u32, image_count, material_alloc)
		for j in 0 ..< image_count {
			object_state.descriptor_states[i].generations[j] = INVALID_ID
			object_state.descriptor_states[i].ids[j] = INVALID_ID
		}
	}

	// Allocate descriptor sets.
	layouts := make([]vk.DescriptorSetLayout, image_count)
	defer delete(layouts)
	for i in 0 ..< image_count {
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
		l.log_error("Error allocating descriptor sets in shader!")
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
		l.log_error("Error freeing object shader descriptor sets!")
	}

	for i in 0 ..< u32(VULKAN_MATERIAL_SHADER_INSTANCE_DESCRIPTOR_COUNT) {
		for j in 0 ..< u32(3) {
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

