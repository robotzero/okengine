package core

import vk "vendor:vulkan"
import arr "../containers"
import "core:fmt"

vulkan_swapchain_create :: proc(
    vk_context: ^vulkan_context,
    width: u32,
    height: u32,
    out_swapchain: ^vulkan_swapchain) {
    // Simply create a new one.
    create(&v_context, width, height, out_swapchain)
}

vulkan_swapchain_recreate :: proc(
    v_context: ^vulkan_context,
    width: u32,
    height: u32,
    out_swapchain: ^vulkan_swapchain) {
    // Destroy the old and create a new one.
    destroy(v_context, out_swapchain)
    create(v_context, width, height, out_swapchain)
}

vulkan_swapchain_destroy :: proc(
    v_context: ^vulkan_context,
    swapchain: ^vulkan_swapchain) {
    destroy(v_context, swapchain)
}

vulkan_swapchain_acquire_next_image_index :: proc(
    v_context: ^vulkan_context,
    swapchain: ^vulkan_swapchain,
    timeout_ns: u64,
    image_available_semaphore: vk.Semaphore,
    fence: vk.Fence,
    out_image_index: ^u32) -> bool {

    result : vk.Result = vk.AcquireNextImageKHR(
        v_context.device.logical_device,
        swapchain.handle,
        timeout_ns,
        image_available_semaphore,
        fence,
        out_image_index)

    
    if result == vk.Result.ERROR_OUT_OF_DATE_KHR {
        // Trigger swapchain recreation, then boot out of the render loop.
        vulkan_swapchain_recreate(v_context, v_context.framebuffer_width, v_context.framebuffer_height, swapchain)
        return false
    } else if (result != vk.Result.SUCCESS && result != vk.Result.SUBOPTIMAL_KHR) {
        log_fatal("Failed to acquire swapchain image!")
        return false
    }

    // Increment (and loop) the index.
    v_context.current_frame = (v_context.current_frame + 1) % cast(u32)swapchain.max_frames_in_flight

    return true
}

vulkan_swapchain_present :: proc(
    v_context: ^vulkan_context,
    swapchain: ^vulkan_swapchain,
    graphics_queue: vk.Queue,
    present_queue: vk.Queue,
    render_complete_semaphore: ^vk.Semaphore,
    present_image_index: u32) {

    present_image_index := present_image_index

    // Return the image to the swapchain for presentation.
    present_info : vk.PresentInfoKHR = {sType = vk.StructureType.PRESENT_INFO_KHR}
    present_info.waitSemaphoreCount = 1
    present_info.pWaitSemaphores = render_complete_semaphore
    present_info.swapchainCount = 1
    present_info.pSwapchains = &swapchain.handle
    present_info.pImageIndices = &present_image_index
    present_info.pResults = nil

    result : vk.Result = vk.QueuePresentKHR(present_queue, &present_info)
    if result == vk.Result.ERROR_OUT_OF_DATE_KHR || result == vk.Result.SUBOPTIMAL_KHR {
        // Swapchain is out of date, suboptimal or a framebuffer resize has occurred. Trigger swapchain recreation.
        vulkan_swapchain_recreate(v_context, v_context.framebuffer_width, v_context.framebuffer_height, swapchain)
    } else if (result != vk.Result.SUCCESS) {
        log_fatal("Failed to present swap chain image!")
    }
}

@(private)
create :: proc(v_context: ^vulkan_context, width: u32, height: u32, swapchain: ^vulkan_swapchain) {
    swapchain_extent : vk.Extent2D = {width, height}
    swapchain.max_frames_in_flight = 2

    // Choose a swap surface format.
    found : bool = false
    for i in 0..<v_context.device.swapchain_support.format_count {
        format := v_context.device.swapchain_support.formats[i]
        if format.format == vk.Format.B8G8R8A8_UNORM &&
            format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
            swapchain.image_format = format
            found = true
            break
        }
    }

    if !found {
        swapchain.image_format = v_context.device.swapchain_support.formats[0]
    }


    present_mode : vk.PresentModeKHR = vk.PresentModeKHR.FIFO
    for i in 0..<v_context.device.swapchain_support.present_mode_count {
        mode := v_context.device.swapchain_support.present_modes[i]
        if mode == vk.PresentModeKHR.MAILBOX {
            present_mode = mode
            break
        }
    }

    // Requery swapchain support.
    vulkan_device_query_swapchain_support(
        v_context.device.physical_device,
        v_context.surface,
        &v_context.device.swapchain_support)

    // Swapchain extent
    if v_context.device.swapchain_support.capabilities.currentExtent.width != max(u32) {
        swapchain_extent = v_context.device.swapchain_support.capabilities.currentExtent
    }

    // Clamp to the value allowed by the GPU.
    min : vk.Extent2D = v_context.device.swapchain_support.capabilities.minImageExtent
    max : vk.Extent2D = v_context.device.swapchain_support.capabilities.maxImageExtent
    swapchain_extent.width = clamp(swapchain_extent.width, min.width, max.width)
    swapchain_extent.height = clamp(swapchain_extent.height, min.height, max.height)

    image_count : u32 = v_context.device.swapchain_support.capabilities.minImageCount + 1
    if v_context.device.swapchain_support.capabilities.maxImageCount > 0 && image_count > v_context.device.swapchain_support.capabilities.maxImageCount {
        image_count = v_context.device.swapchain_support.capabilities.maxImageCount
    }

    // Swapchain create info
    swapchain_create_info : vk.SwapchainCreateInfoKHR = {sType = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR}
    swapchain_create_info.surface = v_context.surface
    swapchain_create_info.minImageCount = image_count
    swapchain_create_info.imageFormat = swapchain.image_format.format
    swapchain_create_info.imageColorSpace = swapchain.image_format.colorSpace
    swapchain_create_info.imageExtent = swapchain_extent
    swapchain_create_info.imageArrayLayers = 1
    swapchain_create_info.imageUsage = {vk.ImageUsageFlag.COLOR_ATTACHMENT}

    // Setup the queue family indices
    if v_context.device.graphics_queue_index != v_context.device.present_queue_index {
        queueFamilyIndices : []u32 = {
            cast(u32)v_context.device.graphics_queue_index,
            cast(u32)v_context.device.present_queue_index,
        }
        swapchain_create_info.imageSharingMode = vk.SharingMode.CONCURRENT
        swapchain_create_info.queueFamilyIndexCount = 2
        swapchain_create_info.pQueueFamilyIndices = raw_data(queueFamilyIndices)
    } else {
        swapchain_create_info.imageSharingMode = vk.SharingMode.EXCLUSIVE
        swapchain_create_info.queueFamilyIndexCount = 0
        swapchain_create_info.pQueueFamilyIndices = nil
    }

    swapchain_create_info.preTransform = v_context.device.swapchain_support.capabilities.currentTransform
    swapchain_create_info.compositeAlpha = {vk.CompositeAlphaFlagKHR.OPAQUE}
    swapchain_create_info.presentMode = present_mode
    swapchain_create_info.clipped = true
    swapchain_create_info.oldSwapchain = vk.SwapchainKHR{}

    assert(vk.CreateSwapchainKHR(v_context.device.logical_device, &swapchain_create_info, v_context.allocator, &swapchain.handle) == vk.Result.SUCCESS)

    // Start with a zero frame index.
    v_context.current_frame = 0

    // Images
    swapchain.image_count = 0
    assert(vk.GetSwapchainImagesKHR(v_context.device.logical_device, swapchain.handle, &swapchain.image_count, nil) == vk.Result.SUCCESS)
    if swapchain.images == nil {
        swapchain.images = arr.darray_create(cast(u64)swapchain.image_count, vk.Image)
    }
    assert(vk.GetSwapchainImagesKHR(v_context.device.logical_device, swapchain.handle, &swapchain.image_count, raw_data(swapchain.images)) == vk.Result.SUCCESS)

    if swapchain.views == nil {
        swapchain.views = arr.darray_create(cast(u64)swapchain.image_count, vk.ImageView)
    }

    // Views
    for _, index in swapchain.images {
        view_info : vk.ImageViewCreateInfo = {sType = vk.StructureType.IMAGE_VIEW_CREATE_INFO}
        view_info.image = swapchain.images[index]
        view_info.viewType = vk.ImageViewType.D2
        view_info.format = swapchain.image_format.format
        view_info.subresourceRange.aspectMask = {vk.ImageAspectFlag.COLOR}
        view_info.subresourceRange.baseMipLevel = 0
        view_info.subresourceRange.levelCount = 1
        view_info.subresourceRange.baseArrayLayer = 0
        view_info.subresourceRange.layerCount = 1
        assert(vk.CreateImageView(v_context.device.logical_device, &view_info, v_context.allocator, &swapchain.views[index]) == vk.Result.SUCCESS)
    }

    // Depth resources
    if !vulkan_device_detect_depth_format(&v_context.device) {
       v_context.device.depth_format = vk.Format.UNDEFINED
        log_fatal("Failed to find a supported format!")
    }

    // Create depth image and its view.
    vulkan_image_create(
        v_context,
        vk.ImageType.D2,
        swapchain_extent.width,
        swapchain_extent.height,
        v_context.device.depth_format,
        vk.ImageTiling.OPTIMAL,
        vk.ImageUsageFlag.DEPTH_STENCIL_ATTACHMENT,
        vk.MemoryPropertyFlag.DEVICE_LOCAL,
        true,
        vk.ImageAspectFlag.DEPTH,
        &swapchain.depth_attachment)

    log_info("Swapchain created successfully.")
}

@(private)
destroy :: proc(v_context: ^vulkan_context, swapchain: ^vulkan_swapchain) {
    arr.darray_destroy(swapchain.images)
    arr.darray_destroy(swapchain.views)
    vk.DeviceWaitIdle(v_context.device.logical_device)
    vulkan_image_destroy(v_context, &swapchain.depth_attachment)

    // Only destroy the views, not the images, since those are owned by the swapchain and are thus
    // destroyed when it is.
    for view in swapchain.views {
        vk.DestroyImageView(v_context.device.logical_device, view, v_context.allocator)
    }

    vk.DestroySwapchainKHR(v_context.device.logical_device, swapchain.handle, v_context.allocator)
}
