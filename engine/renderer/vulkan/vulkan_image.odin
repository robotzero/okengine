package vulkan_renderer

import l "../../logger"
import vk "vendor:vulkan"

vulkan_image_create :: proc(
	v_context: ^vulkan_context,
	image_type: vk.ImageType,
	width: u32,
	height: u32,
	format: vk.Format,
	tiling: vk.ImageTiling,
	usage: vk.ImageUsageFlags,
	memory_flags: vk.MemoryPropertyFlags,
	create_view: b32,
	view_aspect_flags: vk.ImageAspectFlags,
	out_image: ^vulkan_image,
) {

	// Copy params
	out_image.width = width
	out_image.height = height

	// Creation info.
	image_create_info: vk.ImageCreateInfo = {
		sType         = vk.StructureType.IMAGE_CREATE_INFO,
		imageType     = vk.ImageType.D2,
		mipLevels     = 1, // TODO: Support mip mapping
		arrayLayers   = 1, // TODO: Support number of layers in the image.
		format        = format,
		tiling        = tiling,
		initialLayout = vk.ImageLayout.UNDEFINED,
		usage         = usage,
		samples       = {vk.SampleCountFlag._1}, // TODO: Configurable sample count.
		sharingMode   = vk.SharingMode.EXCLUSIVE, // TODO: Configurable sharing mode.
	}

	image_create_info.extent.width = width
	image_create_info.extent.height = height
	image_create_info.extent.depth = 1

	assert(
		vk.CreateImage(
			v_context.device.logical_device,
			&image_create_info,
			v_context.allocator,
			&out_image.handle,
		) ==
		vk.Result.SUCCESS,
	)

	// Query memory requirements.
	memory_requirements: vk.MemoryRequirements = {}
	vk.GetImageMemoryRequirements(
		v_context.device.logical_device,
		out_image.handle,
		&memory_requirements,
	)

	memory_type: i32 = v_context.find_memory_index_proc(
		memory_requirements.memoryTypeBits,
		memory_flags,
	)
	if memory_type == -1 {
		l.log_error("Required memory type not found. Image not valid.")
	}

	// Allocate memory
	memory_allocate_info: vk.MemoryAllocateInfo = {
		sType = vk.StructureType.MEMORY_ALLOCATE_INFO,
	}
	memory_allocate_info.allocationSize = memory_requirements.size
	memory_allocate_info.memoryTypeIndex = u32(memory_type)
	assert(
		vk.AllocateMemory(
			v_context.device.logical_device,
			&memory_allocate_info,
			v_context.allocator,
			&out_image.memory,
		) ==
		vk.Result.SUCCESS,
	)

	// Bind the memory
	assert(
		vk.BindImageMemory(
			v_context.device.logical_device,
			out_image.handle,
			out_image.memory,
			0,
		) ==
		vk.Result.SUCCESS,
	) // TODO: configurable memory offset.

	// Create view
	if create_view {
		out_image.view = 0
		vulkan_image_view_create(v_context, format, out_image, view_aspect_flags)
	}
}

vulkan_image_view_create :: proc(
	v_context: ^vulkan_context,
	format: vk.Format,
	image: ^vulkan_image,
	aspect_flags: vk.ImageAspectFlags,
) {
	view_create_info: vk.ImageViewCreateInfo = {}
	view_create_info.sType = vk.StructureType.IMAGE_VIEW_CREATE_INFO
	view_create_info.image = image.handle
	view_create_info.viewType = vk.ImageViewType.D2 // TODO: Make configurable.
	view_create_info.format = format
	view_create_info.subresourceRange.aspectMask = aspect_flags

	// TODO: Make configurable
	view_create_info.subresourceRange.baseMipLevel = 0
	view_create_info.subresourceRange.levelCount = 1
	view_create_info.subresourceRange.baseArrayLayer = 0
	view_create_info.subresourceRange.layerCount = 1

	assert(
		vk.CreateImageView(
			v_context.device.logical_device,
			&view_create_info,
			v_context.allocator,
			&image.view,
		) ==
		vk.Result.SUCCESS,
	)
}

vulkan_image_destroy :: proc(v_context: ^vulkan_context, image: ^vulkan_image) {
	if image.view != 0 {
		vk.DestroyImageView(v_context.device.logical_device, image.view, v_context.allocator)
		image.view = 0
	}
	if image.memory != 0 {
		vk.FreeMemory(v_context.device.logical_device, image.memory, v_context.allocator)
		image.memory = 0
	}
	if image.handle != 0 {
		vk.DestroyImage(v_context.device.logical_device, image.handle, v_context.allocator)
		image.handle = 0
	}
}

// Transition the provided image from old_layout to new_layout
vulkan_image_transition_layout :: proc(
	v_context: ^vulkan_context,
	command_buffer: ^vulkan_command_buffer,
	image: ^vulkan_image,
	format: vk.Format,
	old_layout: vk.ImageLayout,
	new_layout: vk.ImageLayout,
) {
	barrier := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
	}
	barrier.oldLayout = old_layout
	barrier.newLayout = new_layout
	barrier.srcQueueFamilyIndex = u32(v_context.device.graphics_queue_index)
	barrier.dstQueueFamilyIndex = u32(v_context.device.graphics_queue_index)
	barrier.image = image.handle
	barrier.subresourceRange.aspectMask = {vk.ImageAspectFlag.COLOR}
	barrier.subresourceRange.baseMipLevel = 0
	barrier.subresourceRange.levelCount = 1
	barrier.subresourceRange.baseArrayLayer = 0
	barrier.subresourceRange.layerCount = 1

	source_stage: vk.PipelineStageFlags
	dest_stage: vk.PipelineStageFlags

	// Don't care about the old layout - transition to optimal layout.
	l.log_debug("ImageTransition: img=%p old=%d new=%s", image.handle, old_layout, new_layout)
	if vk.CmdPipelineBarrier == nil {
		l.log_fatal("vk.CmdPipelineBarrier is nil")
		return
	}
	if old_layout == .UNDEFINED && new_layout == .TRANSFER_DST_OPTIMAL {
		barrier.srcAccessMask = nil
		barrier.dstAccessMask = {.TRANSFER_WRITE}
		source_stage = {.TOP_OF_PIPE}
		dest_stage = {.TRANSFER}
	} else if old_layout == .TRANSFER_DST_OPTIMAL && new_layout == .SHADER_READ_ONLY_OPTIMAL {
		// Transitioning from a transfer destination layout to a shader-readonly layout.
		barrier.srcAccessMask = {.TRANSFER_WRITE}
		barrier.dstAccessMask = {.SHADER_READ}
		source_stage = {.TRANSFER}
		dest_stage = {.FRAGMENT_SHADER}
	} else {
		l.log_fatal("unsupported layout transition!")
		return
	}

	vk.CmdPipelineBarrier(
		command_buffer.handle,
		source_stage,
		dest_stage,
		{},
		0,
		nil,
		0,
		nil,
		1,
		&barrier,
	)
}

// Copies data in buffer to provided image.
vulkan_image_copy_from_buffer :: proc(
	v_context: ^vulkan_context,
	image: ^vulkan_image,
	buffer: vk.Buffer,
	command_buffer: ^vulkan_command_buffer,
) {
	// Region to copy
	region: vk.BufferImageCopy
	// kzero_memory(&region, size_of(vk.BufferImageCopy))
	region.bufferOffset = 0
	region.bufferRowLength = 0
	region.bufferImageHeight = 0

	region.imageSubresource.aspectMask = {.COLOR}
	region.imageSubresource.mipLevel = 0
	region.imageSubresource.baseArrayLayer = 0
	region.imageSubresource.layerCount = 1

	region.imageExtent.width = image.width
	region.imageExtent.height = image.height
	region.imageExtent.depth = 1

	l.log_debug(
		"CopyBufferToImage: buf=%p img=%p w=%d h=%d",
		buffer,
		image.handle,
		image.width,
		image.height,
	)
	if vk.CmdCopyBufferToImage == nil {
		l.log_fatal("vk.CmdCopyBufferToImage is nil")
		return
	}
	vk.CmdCopyBufferToImage(
		command_buffer.handle,
		buffer,
		image.handle,
		.TRANSFER_DST_OPTIMAL,
		1,
		&region,
	)
}

