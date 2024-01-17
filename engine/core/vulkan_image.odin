package core

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
    out_image: ^vulkan_image) {

    // Copy params
    out_image.width = width
    out_image.height = height

    // Creation info.
    image_create_info: vk.ImageCreateInfo = {
		sType = vk.StructureType.IMAGE_CREATE_INFO,
    	imageType = vk.ImageType.D2,
    	extent.width = width,
    	extent.height = height,
    	extent.depth = 1,  // TODO: Support configurable depth.
    	mipLevels = 4,     // TODO: Support mip mapping
    	arrayLayers = 1,   // TODO: Support number of layers in the image.
    	format = format,
    	tiling = tiling,
    	initialLayout = vk.ImageLayout.UNDEFINED,
    	usage = usage,
    	samples = vk.SampleCountFlag._1,          // TODO: Configurable sample count.
    	sharingMode = vk.SharingMode.EXCLUSIVE,  // TODO: Configurable sharing mode.
	}

    assert(vk.CreateImage(context.device.logical_device, &image_create_info, context.allocator, &out_image.handle) == vk.Result.SUCCESS)

    // Query memory requirements.
    memory_requirements: vk.MemoryRequirements = {}
    vk.GetImageMemoryRequirements(context->device.logical_device, out_image->handle, &memory_requirements)

    memory_type : i32 = context.find_memory_index(memory_requirements.memoryTypeBits, memory_flags)
    if memory_type == -1 {
        log_error("Required memory type not found. Image not valid.")
    }

    // Allocate memory
    vk.MemoryAllocateInfo memory_allocate_info = {vk.StructureType.MEMORY_ALLOCATE_INFO}
    memory_allocate_info.allocationSize = memory_requirements.size
    memory_allocate_info.memoryTypeIndex = memory_type
    assert(vk.AllocateMemory(context.device.logical_device, &memory_allocate_info, context.allocator, &out_image.memory) == vk.Result.SUCCESS)

    // Bind the memory
    assert(vkBindImageMemory(context.device.logical_device, out_image.handle, out_image.memory, 0) == vk.Result.SUCCESS)  // TODO: configurable memory offset.

    // Create view
    if create_view {
        out_image.view = 0
        vulkan_image_view_create(context, format, out_image, view_aspect_flags)
    }
}

vulkan_image_view_create :: proc(
    vk_context: ^vulkan_context,
    format: vk.Format,
    image: ^vulkan_image,
    aspect_flags: vk.ImageAspectFlags) {
    view_create_info: vk.ImageViewCreateInfo = {vk.StructureType.IMAGE_VIEW_CREATE_INFO}
    view_create_info.image = image.handle
    view_create_info.viewType = vk.ImageViewType.D2  // TODO: Make configurable.
    view_create_info.format = format
    view_create_info.subresourceRange.aspectMask = aspect_flags

    // TODO: Make configurable
    view_create_info.subresourceRange.baseMipLevel = 0
    view_create_info.subresourceRange.levelCount = 1
    view_create_info.subresourceRange.baseArrayLayer = 0
    view_create_info.subresourceRange.layerCount = 1

    assert(vk.CreateImageView(context.device.logical_device, &view_create_info, context.allocator, &image.view) == vk.Result.SUCCESS)
}

vulkan_image_destroy :: proc(v_context: ^vulkan_context, image: ^vulkan_image) {
    if image.view {
        vk.DestroyImageView(context.device.logical_device, image.view, context.allocator)
        image.view = 0
    }
    if image.memory {
        vk.FreeMemory(context.device.logical_device, image.memory, context.allocator)
        image.memory = 0
    }
    if image.handle {
        vk.DestroyImage(context.device.logical_device, image.handle, context.allocator)
        image.handle = 0
    }
}
