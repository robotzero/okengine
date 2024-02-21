package core

import vk "vendor:vulkan"

vulkan_fence_create :: proc(v_context: ^vulkan_context, create_signaled: bool, out_fence: ^vulkan_fence) {
	// Make sure to signal the fence if required.
	out_fence.is_signaled = create_signaled
	fence_create_info : vk.FenceCreateInfo = {
		sType = vk.StructureType.FENCE_CREATE_INFO,
	}
	if out_fence.is_signaled {
		fence_create_info.flags = {{.FENCE_CREATE_SIGNALED_BIT}}
	}

	assert(vk.CreateFence(v_context.device.logical_device, &fence_create_info, v_context.allocator, &out_fence.handle) == vk.Result.SUCCESS)
}

vulkan_fence_destroy :: proc(v_context: ^vulkan_context, fence: ^vulkan_fence) {
	if fence.handle != nil {
		vk.DestroyFence(v_context.device.logical_device, fence.handle, v_context.allocator)
		fence.handle = nil
	}
	fence.is_signaled = false
}

vulkan_fence_wait :: proc(v_context: ^vulkan_context, fence: ^vulkan_fence, timeout_ns: u64) -> bool {
	if fence.is_signaled == false {
		result : vk.Result = vk.WaitForFences(
			v_context.device.logical_device,
			1,
			&fence.handle,
			true,
			timeout_ns,
		)

		result := false
		switch (result) {
			case vk.Result.SUCCESS:
				fence.is_signaled = true
				result = true
			case vk.Result.TIMEOUT:
				log_warning("vk_fence wait - Timed out")
			case vk.Result.ERROR_DEVICE_LOST:
				log_error("vk_fence_wait - VK_ERROR_DEVICE_LOST")
			case vk.Result.ERROR_OUT_OF_HOST_MEMORY:
				log_error("vk_fence_wait = VK_ERROR_OUT_OF_HOST_MEMORY")
			case vk.Result.ERROR_OUT_OF_DEVICE_MEMORY:
				log_error("vk_fence wait = VK_ERROR_OUT_OF_DEVICE_MEMORY")
			case:
				log_error("vk_fence_wait - An unknown error has occured.")
		}
	} else {
		result = true
	}
	return result
}

vulkan_fence_reset :: proc(v_context: ^vulkan_context, fence: ^vulkan_fence) {
	if fence.is_signaled {
		assert(vk.ResetFences(v_context.device.logical_device, 1 &fence.handle) == vk.Result.SUCCESS)
		fence.is_signaled = false
	}
}
