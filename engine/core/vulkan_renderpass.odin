package core

import vk "vendor:vulkan"

vulkan_renderpass_create :: proc(
	v_context: ^vulkan_context,
	out_renderpass: ^vulkan_renderpass,
	x: f32, y: f32, w: f32, h: f32,
	r: f32, g: f32, b: f32, a: f32,
	depth: f32,
	sencil: u32) {
		// Main subpass
		subpass : vk.SubpassDescription = {}
		subpass.pipelineBindPoint = vk.PipelineBindPoint.GRAPHICS

		// Attachments TODO: make this configurable.
		attachment_description_count :: 2
		attachment_descriptions : [attachment_description_count]vk.AttachmentDescription = {{},{}}

		// Color attachment
		color_attachment : vk.AttachmentDescription = {
			format = v_context.swapchain.image_format.format, // @TODO: configurable
			samples = {vk.SampleCountFlag._1},
			loadOp = vk.AttachmentLoadOp.CLEAR,
			storeOp = vk.AttachmentStoreOp.STORE,
			stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout = vk.ImageLayout.UNDEFINED, // Do not expect any particular layout before render pass starts.
			finalLayout = vk.ImageLayout.PRESENT_SRC_KHR, // Transitioned to after the render pass
			flags = nil,
		}

		attachment_descriptions[0] = color_attachment

		color_attachment_reference : vk.AttachmentReference = {
			attachment = 0, // Attachment description array index
			layout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
		}

		subpass.colorAttachmentCount = 1
		subpass.pColorAttachments = &color_attachment_reference

		// Depth attachment, if there is one
		depth_attachment: vk.AttachmentDescription = {
			format = v_context.device.depth_format,
			samples = {vk.SampleCountFlag._1},
			loadOp = vk.AttachmentLoadOp.CLEAR,
			storeOp = vk.AttachmentStoreOp.DONT_CARE,
			stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
			stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
			initialLayout = vk.ImageLayout.UNDEFINED,
			finalLayout = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		}

		attachment_descriptions[1] = depth_attachment

		// Depth attachment reference
		depth_attachment_reference : vk.AttachmentReference = {
			attachment = 1,
			layout = vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		}

		// @TODO: other attachment types (input, resolve, preserve)

		// Depth stencil data.
		subpass.pDepthStencilAttachment = &depth_attachment_reference

		// Input from a shader
		subpass.inputAttachmentCount = 0
		subpass.pInputAttachments = nil
		
		// Attachments used for multisampling colour attachments
		subpass.pResolveAttachments = nil

		// Attachments not used in this subpass, but must be preserved for the nex
		subpass.preserveAttachmentCount = 0
		subpass.pPreserveAttachments = nil

		// Render pass dependencides. @TODO: make this configurable.
		dependency : vk.SubpassDependency = {
			srcSubpass = vk.SUBPASS_EXTERNAL,
			dstSubpass = 0,
			srcStageMask = {vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT},
			srcAccessMask = nil,
			dstStageMask = {vk.PipelineStageFlag.COLOR_ATTACHMENT_OUTPUT},
			dstAccessMask = {vk.AccessFlag.COLOR_ATTACHMENT_READ, vk.AccessFlag.COLOR_ATTACHMENT_WRITE},
			dependencyFlags = nil,
		}

		// Render pass create.
		render_pass_create_info : vk.RenderPassCreateInfo = {
			sType = vk.StructureType.RENDER_PASS_CREATE_INFO,
			attachmentCount = attachment_description_count,
			pAttachments = &attachment_descriptions[0],
			subpassCount = 1,
			pSubpasses = &subpass,
			dependencyCount = 1,
			pDependencies = &dependency,
			pNext = nil,
			flags = nil,
		}

		assert(vk.CreateRenderPass(v_context.device.logical_device, &render_pass_create_info, v_context.allocator, &out_renderpass.handle) == vk.Result.SUCCESS)
	}

vulkan_renderpass_destroy :: proc(v_context: ^vulkan_context, renderpass: ^vulkan_renderpass) {
	if renderpass != nil && renderpass.handle != 0 {
		vk.DestroyRenderPass(v_context.device.logical_device, renderpass.handle, v_context.allocator)
	}
}

vulkan_renderpass_begin :: proc(command_buffer: ^vulkan_command_buffer, renderpass: ^vulkan_renderpass, frame_buffer: vk.Framebuffer) {
	begin_info : vk.RenderPassBeginInfo = {
		sType = vk.StructureType.RENDER_PASS_BEGIN_INFO,
		framebuffer = frame_buffer,
		renderArea = {
			offset = {
				x = cast(i32)renderpass.x,
				y = cast(i32)renderpass.y,
			},
			extent = {
				width = cast(u32)renderpass.w,
				height = cast(u32)renderpass.h,
			},
		},
	}

	clear_values : [2]vk.ClearValue = {{},{}}
	kzero_memory(&clear_values, size_of(vk.ClearValue) * 2)

	clear_values[0].color.float32 = [4]f32{renderpass.r, renderpass.g, renderpass.b, renderpass.a}
	// clear_values[0].color.float32[0] = renderpass.r;
 //    clear_values[0].color.float32[1] = renderpass.g;
 //    clear_values[0].color.float32[2] = renderpass.b;
 //    clear_values[0].color.float32[3] = renderpass.a;
    clear_values[1].depthStencil.depth = renderpass.depth;
    clear_values[1].depthStencil.stencil = renderpass.stencil;

	begin_info.clearValueCount = 2
	begin_info.pClearValues = &clear_values[0]

	vk.CmdBeginRenderPass(command_buffer.handle, &begin_info, vk.SubpassContents.INLINE)
	command_buffer.state = .COMMAND_BUFFER_STATE_IN_RENDER_PASS
}

vulkan_renderpass_end :: proc(command_buffer: ^vulkan_command_buffer, renderpass: ^vulkan_renderpass) {
	vk.CmdEndRenderPass(command_buffer.handle)
	command_buffer.state = .COMMAND_BUFFER_STATE_RECORDING
}

