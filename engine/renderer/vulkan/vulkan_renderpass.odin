package vulkan_renderer

import "../../okmath"
import vk "vendor:vulkan"

vulkan_renderpass_create :: proc(
	v_context: ^vulkan_context,
	out_renderpass: ^vulkan_renderpass,
	render_area: okmath.vec4,
	clear_colour: okmath.vec4,
	depth: f32,
	stencil: u32,
	clear_flags: u8,
	has_prev_pass: bool,
	has_next_pass: bool,
) {
	out_renderpass.render_area = render_area
	out_renderpass.clear_colour = clear_colour
	out_renderpass.depth = depth
	out_renderpass.stencil = stencil
	out_renderpass.clear_flags = clear_flags
	out_renderpass.has_prev_pass = has_prev_pass
	out_renderpass.has_next_pass = has_next_pass

	do_clear_colour := (clear_flags & u8(renderpass_clear_flag.COLOUR)) != 0
	do_clear_depth  := (clear_flags & u8(renderpass_clear_flag.DEPTH)) != 0

	// Main subpass
	subpass: vk.SubpassDescription = {}
	subpass.pipelineBindPoint = vk.PipelineBindPoint.GRAPHICS

	// Attachments
	attachment_description_count: u32 = do_clear_depth ? 2 : 1
	attachment_descriptions: [2]vk.AttachmentDescription

	// Color attachment
	color_attachment: vk.AttachmentDescription = {
		format         = v_context.swapchain.image_format.format,
		samples        = {vk.SampleCountFlag._1},
		loadOp         = do_clear_colour ? vk.AttachmentLoadOp.CLEAR : vk.AttachmentLoadOp.LOAD,
		storeOp        = vk.AttachmentStoreOp.STORE,
		stencilLoadOp  = vk.AttachmentLoadOp.DONT_CARE,
		stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
		// If there is a previous pass, expect it already in colour attachment optimal layout.
		initialLayout  = has_prev_pass ? vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL : vk.ImageLayout.UNDEFINED,
		// If there is a next pass, keep in colour attachment optimal; otherwise transition to present.
		finalLayout    = has_next_pass ? vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL : vk.ImageLayout.PRESENT_SRC_KHR,
		flags          = nil,
	}

	attachment_descriptions[0] = color_attachment

	color_attachment_reference: vk.AttachmentReference = {
		attachment = 0,
		layout     = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
	}

	subpass.colorAttachmentCount = 1
	subpass.pColorAttachments = &color_attachment_reference

	// Depth attachment (only when DEPTH flag is set)
	depth_attachment_reference: vk.AttachmentReference
	if do_clear_depth {
		depth_attachment: vk.AttachmentDescription = {
			format         = v_context.device.depth_format,
			samples        = {vk.SampleCountFlag._1},
			loadOp         = vk.AttachmentLoadOp.CLEAR,
			storeOp        = vk.AttachmentStoreOp.DONT_CARE,
			stencilLoadOp  = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout  = vk.ImageLayout.UNDEFINED,
			finalLayout    = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		}
		attachment_descriptions[1] = depth_attachment

		depth_attachment_reference = vk.AttachmentReference {
			attachment = 1,
			layout     = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		}
		subpass.pDepthStencilAttachment = &depth_attachment_reference
	} else {
		subpass.pDepthStencilAttachment = nil
	}

	// Input from a shader
	subpass.inputAttachmentCount = 0
	subpass.pInputAttachments = nil

	// Attachments used for multisampling colour attachments
	subpass.pResolveAttachments = nil

	// Attachments not used in this subpass, but must be preserved for the next
	subpass.preserveAttachmentCount = 0
	subpass.pPreserveAttachments = nil

	// Render pass dependencies
	dependency: vk.SubpassDependency = {
		srcSubpass      = vk.SUBPASS_EXTERNAL,
		dstSubpass      = 0,
		srcStageMask    = {vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT},
		srcAccessMask   = nil,
		dstStageMask    = {vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT},
		dstAccessMask   = {
			vk.AccessFlag.COLOR_ATTACHMENT_READ,
			vk.AccessFlag.COLOR_ATTACHMENT_WRITE,
		},
		dependencyFlags = nil,
	}

	// Render pass create
	render_pass_create_info: vk.RenderPassCreateInfo = {
		sType           = vk.StructureType.RENDER_PASS_CREATE_INFO,
		attachmentCount = attachment_description_count,
		pAttachments    = &attachment_descriptions[0],
		subpassCount    = 1,
		pSubpasses      = &subpass,
		dependencyCount = 1,
		pDependencies   = &dependency,
		pNext           = nil,
		flags           = nil,
	}

	assert(
		vk.CreateRenderPass(
			v_context.device.logical_device,
			&render_pass_create_info,
			v_context.allocator,
			&out_renderpass.handle,
		) ==
		vk.Result.SUCCESS,
	)
}

vulkan_renderpass_destroy :: proc(v_context: ^vulkan_context, renderpass: ^vulkan_renderpass) {
	if renderpass != nil && renderpass.handle != 0 {
		vk.DestroyRenderPass(
			v_context.device.logical_device,
			renderpass.handle,
			v_context.allocator,
		)
	}
}

vulkan_renderpass_begin :: proc(
	command_buffer: ^vulkan_command_buffer,
	renderpass: ^vulkan_renderpass,
	frame_buffer: vk.Framebuffer,
) {
	begin_info: vk.RenderPassBeginInfo = {
		sType       = vk.StructureType.RENDER_PASS_BEGIN_INFO,
		renderPass  = renderpass.handle,
		framebuffer = frame_buffer,
	}
	begin_info.renderArea.offset = {
		x = i32(renderpass.render_area.x),
		y = i32(renderpass.render_area.y),
	}
	begin_info.renderArea.extent = {
		width  = u32(renderpass.render_area.z),
		height = u32(renderpass.render_area.w),
	}

	do_clear_colour := (renderpass.clear_flags & u8(renderpass_clear_flag.COLOUR)) != 0
	do_clear_depth  := (renderpass.clear_flags & u8(renderpass_clear_flag.DEPTH)) != 0
	do_clear_stencil := (renderpass.clear_flags & u8(renderpass_clear_flag.STENCIL)) != 0

	clear_value_count: u32 = 0
	clear_values: [2]vk.ClearValue

	if do_clear_colour {
		clear_values[clear_value_count].color.float32 = [4]f32{
			renderpass.clear_colour.r,
			renderpass.clear_colour.g,
			renderpass.clear_colour.b,
			renderpass.clear_colour.a,
		}
		clear_value_count += 1
	} else {
		// Still need a slot even if not clearing
		clear_value_count += 1
	}

	if do_clear_depth {
		clear_values[clear_value_count].color.float32 = [4]f32{
			renderpass.clear_colour.r,
			renderpass.clear_colour.g,
			renderpass.clear_colour.b,
			renderpass.clear_colour.a,
		}
		clear_values[clear_value_count].depthStencil.depth = renderpass.depth
		if do_clear_stencil {
			clear_values[clear_value_count].depthStencil.stencil = renderpass.stencil
		}
		clear_value_count += 1
	}

	begin_info.clearValueCount = clear_value_count
	begin_info.pClearValues = clear_value_count > 0 ? &clear_values[0] : nil

	vk.CmdBeginRenderPass(command_buffer.handle, &begin_info, vk.SubpassContents.INLINE)
	command_buffer.state = .COMMAND_BUFFER_STATE_IN_RENDER_PASS
}

vulkan_renderpass_end :: proc(
	command_buffer: ^vulkan_command_buffer,
	renderpass: ^vulkan_renderpass,
) {
	vk.CmdEndRenderPass(command_buffer.handle)
	command_buffer.state = .COMMAND_BUFFER_STATE_RECORDING
}
