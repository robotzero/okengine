package core

import "../okmath"
import "core:mem"
import vk "vendor:vulkan"

vulkan_graphics_pipeline_create :: proc(
	v_context: ^vulkan_context,
	renderpass: ^vulkan_renderpass,
	attribute_count: u32,
	attributes: [^]vk.VertexInputAttributeDescription,
	descriptor_set_layout_count: u32,
	descriptor_set_layouts: [^]vk.DescriptorSetLayout,
	stage_count: u32,
	stages: [^]vk.PipelineShaderStageCreateInfo,
	viewport: ^vk.Viewport,
	scissor: ^vk.Rect2D,
	is_wireframe: bool,
	out_pipeline: ^vulkan_pipeline,
) -> bool {
	// Viewport state
	viewport_state := vk.PipelineViewportStateCreateInfo {
		sType         = vk.StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		pViewports    = viewport,
		scissorCount  = 1,
		pScissors     = scissor,
	}

	// Rasterizer
	rasterizer_create_info := vk.PipelineRasterizationStateCreateInfo {
		sType                   = vk.StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		depthClampEnable        = 0,
		rasterizerDiscardEnable = 0,
		polygonMode             = (is_wireframe) ? vk.PolygonMode.LINE : vk.PolygonMode.FILL,
		lineWidth               = 1.0,
		cullMode                = vk.CullModeFlag.BACK,
		frontFace               = vk.FrontFace.COUNTER_CLOCKWISE,
		depthBiasEnable         = 0,
		depthBiasConstantFactor = 0.0,
		depthBiasClamp          = 0.0,
		depthBiasSlopeFactor    = 0.0,
	}

	// Multisampling
	multisampling_create_info := vk.PipelineMultisampleStateCreateInfo {
		sType                 = vk.StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		sampleShadingEnable   = vk.FALSE,
		rasterizationSamples  = vk.SampleCountFlag._1,
		minSampleShading      = 1.0,
		pSampleMask           = nil,
		alphaToCoverageEnable = vk.FALSE,
		alphaToOneEnable      = vk.FALSE,
	}

	// Depth and stencil testing
	depth_stencil := vk.PipelineDepthStencilStateCreateInfo {
		sType                 = vk.StructureType.PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
		depthTestEnable       = vk.TRUE,
		depthWriteEnable      = vk.TRUE,
		depthCompareOp        = vk.CompareOp.LESS,
		depthBoundsTestEnable = vk.FALSE,
		stencilTestEnable     = vk.FALSE,
	}

	// Color blending
	color_blend_attachment_state := vk.PipelineColorBlendAttachmentState {
		blendEnable         = vk.TRUE,
		srcColorBlendFactor = vk.BlendFactor.SRC_ALPHA,
		dstColorBlendFactor = vk.BlendFactor.ONE_MINUS_SRC_ALPHA,
		colorBlendOp        = vk.BlendOp.ADD,
		srcAlphaBlendFactor = vk.BlendFactor.SRC_ALPHA,
		dstAlphaBlendFactor = vk.BlendFactor.ONE_MINUS_SRC_ALPHA,
		alphaBlendOp        = vk.BlendOp.ADD,
		colorWriteMask      = vk.ColorComponentFlag.R | vk.ColorComponentFlag.G | vk.ColorComponentFlag.B | vk.ColorComponentFlag.A,
	}

	color_blend_state_create_info := vk.PipelineColorBlendStateCreateInfo {
		sType           = vk.StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		logicOpEnable   = vk.FALSE,
		logicOp         = vk.LogicOp.COPY,
		attachmentCount = 1,
		pAttachments    = &color_blend_attachment_state,
	}

	// Dynamic state
	dynamic_states: [3]vk.DynamicState = {
		vk.DynamicState.VIEWPORT,
		vk.DynamicState.SCISSOR,
		vk.DynamicState.LINE_WIDTH,
	}

	dynamic_state_create_info := vk.PipelineDynamicStateCreateInfo {
		sType             = vk.StructureType.PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states)),
		pDynamicStates    = &dynamic_states[0],
	}

	// Vertex input
	binding_description := vk.VertexInputBindingDescription {
		binding   = 0,
		stride    = u32(size_of(okmath.vertex_3d)),
		inputRate = vk.VertexInputRate.VERTEX,
	}

	vertex_input_info := vk.PipelineVertexInputStateCreateInfo {
		sType                           = vk.StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount   = 1,
		pVertexBindingDescriptions      = &binding_description,
		vertexAttributeDescriptionCount = attribute_count,
		pVertexAttributeDescriptions    = attributes,
	}

	// Input assembly
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
		sType                  = vk.StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology               = vk.PrimitiveTopology.TRIANGLE_LIST,
		primitiveRestartEnable = vk.FALSE,
	}

	// Pipeline layout
	pipeline_layout_create_info := vk.PipelineLayoutCreateInfo {
		sType          = vk.StructureType.PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = descriptor_set_layout_count,
		pSetLayouts    = descriptor_set_layouts,
	}

	// Create pipeline layout
	// (Replace VK_CHECK with your own error handling helper)
	result := vk.CreatePipelineLayout(
		v_context.device.logical_device,
		&pipeline_layout_create_info,
		v_context.allocator,
		&out_pipeline.pipeline_layout,
	)
	if result != vk.Result.SUCCESS {
		log_error("vkCreatePipelineLayout failed: ...")
		return false
	}

	// Pipeline create
	pipeline_create_info := vk.GraphicsPipelineCreateInfo {
		sType               = vk.StructureType.GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount          = stage_count,
		pStages             = stages,
		pVertexInputState   = &vertex_input_info,
		pInputAssemblyState = &input_assembly,
		pViewportState      = &viewport_state,
		pRasterizationState = &rasterizer_create_info,
		pMultisampleState   = &multisampling_create_info,
		pDepthStencilState  = &depth_stencil,
		pColorBlendState    = &color_blend_state_create_info,
		pDynamicState       = &dynamic_state_create_info,
		pTessellationState  = nil,
		layout              = out_pipeline.pipeline_layout,
		renderPass          = renderpass.handle,
		subpass             = 0,
		basePipelineHandle  = vk.Pipeline(nil),
		basePipelineIndex   = -1,
	}

	result = vk.CreateGraphicsPipelines(
		v_context.device.logical_device,
		vk.PipelineCache(nil),
		1,
		&pipeline_create_info,
		v_context.allocator,
		&out_pipeline.handle,
	)

	if vulkan_result_is_success(result) {
		log_debug("Graphics pipeline created!")
		return true
	}

	log_error("vkCreateGraphicsPipelines failed with %s", vulkan_result_string(result, true))
	return false
}

