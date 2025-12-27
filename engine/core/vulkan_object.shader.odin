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
		0,
		nil,
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
	return true
}

vulkan_object_shader_destroy :: proc(v_context: ^vulkan_context, shader: ^vulkan_object_shader) {
	for i in 0 ..< OBJECT_SHADER_STAGE_COUNT {
		vk.DestroyShaderModule(
			v_context.device.logical_device,
			shader.stages[i].handle,
			v_context.allocator,
		)
		shader.stages[i].handle = 0
	}
}

