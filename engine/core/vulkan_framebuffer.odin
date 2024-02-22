package core

import vk "vendor:vulkan"
import arr "../containers"

vulkan_framebuffer_create :: proc(
	v_context: ^vulkan_context,
	renderpass: ^vulkan_renderpass,
	width: u32,
	height: u32,
	attachment_count: u32,
	attachments: [dynamic]vk.ImageView,
	out_framebuffer: ^vulkan_framebuffer) {
		// Take a copy of the attachments, renderpass and attachments count
		out_framebuffer.attachments = arr.darray_create(cast(u64)len(attachments), vk.ImageView)
		for i in 0..<attachment_count {
			out_framebuffer.attachments[i] = attachments[i]
		}
		out_framebuffer.renderpass = renderpass
		out_framebuffer.attachment_count = attachment_count

		// Creation info
		framebuffer_create_info : vk.FramebufferCreateInfo = {
			sType = vk.StructureType.FRAMEBUFFER_CREATE_INFO,
			renderPass = renderpass.handle,
			attachmentCount = attachment_count,
			pAttachments = &out_framebuffer.attachments[0],
			width = width,
			height = height,
			layers = 1,
		}

		assert(vk.CreateFramebuffer(v_context.device.logical_device, &framebuffer_create_info, v_context.allocator, &out_framebuffer.handle) == vk.Result.SUCCESS)
	}

vulkan_framebuffer_destroy :: proc(v_context: ^vulkan_context, framebuffer: ^vulkan_framebuffer) {
	vk.DestroyFramebuffer(v_context.device.logical_device, framebuffer.handle, v_context.allocator)

	if framebuffer.attachments != nil {
		arr.darray_destroy(framebuffer.attachments)
		framebuffer.attachments = nil
	}
	framebuffer.handle = 0
	framebuffer.attachment_count = 0
	framebuffer.renderpass = nil
}
