package core

import vk "vendor:vulkan"

/**
 * Returns the string representation of result.
 * @param result The result to get the string for.
 * @param get_extended Indicates whether to also return an extended result.
 * @returns The error code and/or extended error message in string form. Defaults to success for unknown result types.
 */
vulkan_result_string :: proc(result: vk.Result, get_extended: bool) -> string {
	// From: https://www.khronos.org/registry/vulkan/specs/1.2-extensions/man/html/VkResult.html
    // Success Codes
    #partial switch (result) {
        case vk.Result.SUCCESS:
            return !get_extended ? "SUCCESS" : "SUCCESS Command successfully completed"
        case vk.Result.NOT_READY:
            return !get_extended ? "NOT_READY" : "NOT_READY A fence or query has not yet completed"
        case vk.Result.TIMEOUT:
            return !get_extended ? "TIMEOUT" : "TIMEOUT A wait operation has not completed in the specified time"
        case vk.Result.EVENT_SET:
            return !get_extended ? "EVENT_SET" : "EVENT_SET An event is signaled"
        case vk.Result.EVENT_RESET:
            return !get_extended ? "EVENT_RESET" : "EVENT_RESET An event is unsignaled"
        case vk.Result.INCOMPLETE:
            return !get_extended ? "INCOMPLETE" : "INCOMPLETE A return array was too small for the result"
        case vk.Result.SUBOPTIMAL_KHR:
            return !get_extended ? "SUBOPTIMAL_KHR" : "SUBOPTIMAL_KHR A swapchain no longer matches the surface properties exactly, but can still be used to present to the surface successfully."
        case vk.Result.THREAD_IDLE_KHR:
            return !get_extended ? "THREAD_IDLE_KHR" : "THREAD_IDLE_KHR A deferred operation is not complete but there is currently no work for this thread to do at the time of this call."
        case vk.Result.THREAD_DONE_KHR:
            return !get_extended ? "THREAD_DONE_KHR" : "THREAD_DONE_KHR A deferred operation is not complete but there is no work remaining to assign to additional threads."
        case vk.Result.OPERATION_DEFERRED_KHR:
            return !get_extended ? "OPERATION_DEFERRED_KHR" : "OPERATION_DEFERRED_KHR A deferred operation was requested and at least some of the work was deferred."
        case vk.Result.OPERATION_NOT_DEFERRED_KHR:
            return !get_extended ? "OPERATION_NOT_DEFERRED_KHR" : "OPERATION_NOT_DEFERRED_KHR A deferred operation was requested and no operations were deferred."
        case vk.Result.PIPELINE_COMPILE_REQUIRED_EXT:
            return !get_extended ? "VK_PIPELINE_COMPILE_REQUIRED_EXT" : "VK_PIPELINE_COMPILE_REQUIRED_EXT A requested pipeline creation would have required compilation, but the application requested compilation to not be performed."

        // Error codes
        case vk.Result.ERROR_OUT_OF_HOST_MEMORY:
            return !get_extended ? "VK_ERROR_OUT_OF_HOST_MEMORY" : "VK_ERROR_OUT_OF_HOST_MEMORY A host memory allocation has failed."
        case vk.Result.ERROR_OUT_OF_DEVICE_MEMORY:
            return !get_extended ? "VK_ERROR_OUT_OF_DEVICE_MEMORY" : "VK_ERROR_OUT_OF_DEVICE_MEMORY A device memory allocation has failed."
        case vk.Result.ERROR_INITIALIZATION_FAILED:
            return !get_extended ? "VK_ERROR_INITIALIZATION_FAILED" : "VK_ERROR_INITIALIZATION_FAILED Initialization of an object could not be completed for implementation-specific reasons."
        case vk.Result.ERROR_DEVICE_LOST:
            return !get_extended ? "VK_ERROR_DEVICE_LOST" : "VK_ERROR_DEVICE_LOST The logical or physical device has been lost. See Lost Device"
        case vk.Result.ERROR_MEMORY_MAP_FAILED:
            return !get_extended ? "VK_ERROR_MEMORY_MAP_FAILED" : "VK_ERROR_MEMORY_MAP_FAILED Mapping of a memory object has failed."
        case vk.Result.ERROR_LAYER_NOT_PRESENT:
            return !get_extended ? "VK_ERROR_LAYER_NOT_PRESENT" : "VK_ERROR_LAYER_NOT_PRESENT A requested layer is not present or could not be loaded."
        case vk.Result.ERROR_EXTENSION_NOT_PRESENT:
            return !get_extended ? "VK_ERROR_EXTENSION_NOT_PRESENT" : "VK_ERROR_EXTENSION_NOT_PRESENT A requested extension is not supported."
        case vk.Result.ERROR_FEATURE_NOT_PRESENT:
            return !get_extended ? "VK_ERROR_FEATURE_NOT_PRESENT" : "VK_ERROR_FEATURE_NOT_PRESENT A requested feature is not supported."
        case vk.Result.ERROR_INCOMPATIBLE_DRIVER:
            return !get_extended ? "VK_ERROR_INCOMPATIBLE_DRIVER" : "VK_ERROR_INCOMPATIBLE_DRIVER The requested version of Vulkan is not supported by the driver or is otherwise incompatible for implementation-specific reasons."
        case vk.Result.ERROR_TOO_MANY_OBJECTS:
            return !get_extended ? "VK_ERROR_TOO_MANY_OBJECTS" : "VK_ERROR_TOO_MANY_OBJECTS Too many objects of the type have already been created."
        case vk.Result.ERROR_FORMAT_NOT_SUPPORTED:
            return !get_extended ? "VK_ERROR_FORMAT_NOT_SUPPORTED" : "VK_ERROR_FORMAT_NOT_SUPPORTED A requested format is not supported on this device."
        case vk.Result.ERROR_FRAGMENTED_POOL:
            return !get_extended ? "VK_ERROR_FRAGMENTED_POOL" : "VK_ERROR_FRAGMENTED_POOL A pool allocation has failed due to fragmentation of the pool’s memory. This must only be returned if no attempt to allocate host or device memory was made to accommodate the new allocation. This should be returned in preference to vk.Result.ERROR_OUT_OF_POOL_MEMORY, but only if the implementation is certain that the pool allocation failure was due to fragmentation."
        case vk.Result.ERROR_SURFACE_LOST_KHR:
            return !get_extended ? "VK_ERROR_SURFACE_LOST_KHR" : "VK_ERROR_SURFACE_LOST_KHR A surface is no longer available."
        case vk.Result.ERROR_NATIVE_WINDOW_IN_USE_KHR:
            return !get_extended ? "VK_ERROR_NATIVE_WINDOW_IN_USE_KHR" : "VK_ERROR_NATIVE_WINDOW_IN_USE_KHR The requested window is already in use by Vulkan or another API in a manner which prevents it from being used again."
        case vk.Result.ERROR_OUT_OF_DATE_KHR:
            return !get_extended ? "VK_ERROR_OUT_OF_DATE_KHR" : "VK_ERROR_OUT_OF_DATE_KHR A surface has changed in such a way that it is no longer compatible with the swapchain, and further presentation requests using the swapchain will fail. Applications must query the new surface properties and recreate their swapchain if they wish to continue presenting to the surface."
        case vk.Result.ERROR_INCOMPATIBLE_DISPLAY_KHR:
            return !get_extended ? "VK_ERROR_INCOMPATIBLE_DISPLAY_KHR" : "VK_ERROR_INCOMPATIBLE_DISPLAY_KHR The display used by a swapchain does not use the same presentable image layout, or is incompatible in a way that prevents sharing an image."
        case vk.Result.ERROR_INVALID_SHADER_NV:
            return !get_extended ? "VK_ERROR_INVALID_SHADER_NV" : "VK_ERROR_INVALID_SHADER_NV One or more shaders failed to compile or link. More details are reported back to the application via vk.Result.EXT_debug_report if enabled."
        case vk.Result.ERROR_OUT_OF_POOL_MEMORY:
            return !get_extended ? "VK_ERROR_OUT_OF_POOL_MEMORY" : "VK_ERROR_OUT_OF_POOL_MEMORY A pool memory allocation has failed. This must only be returned if no attempt to allocate host or device memory was made to accommodate the new allocation. If the failure was definitely due to fragmentation of the pool, vk.Result.ERROR_FRAGMENTED_POOL should be returned instead."
        case vk.Result.ERROR_INVALID_EXTERNAL_HANDLE:
            return !get_extended ? "VK_ERROR_INVALID_EXTERNAL_HANDLE" : "VK_ERROR_INVALID_EXTERNAL_HANDLE An external handle is not a valid handle of the specified type."
        case vk.Result.ERROR_FRAGMENTATION:
            return !get_extended ? "VK_ERROR_FRAGMENTATION" : "VK_ERROR_FRAGMENTATION A descriptor pool creation has failed due to fragmentation."
        case vk.Result.ERROR_INVALID_DEVICE_ADDRESS_EXT:
            return !get_extended ? "VK_ERROR_INVALID_DEVICE_ADDRESS_EXT" : "VK_ERROR_INVALID_DEVICE_ADDRESS_EXT A buffer creation failed because the requested address is not available."
        // NOTE: Same as above
        //case vk.Result.ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS:
        //    return !get_extended ? "VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS" :"VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS A buffer creation or memory allocation failed because the requested address is not available. A shader group handle assignment failed because the requested shader group handle information is no longer valid."
        case vk.Result.ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT:
            return !get_extended ? "VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT" : "VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT An operation on a swapchain created with vk.Result.FULL_SCREEN_EXCLUSIVE_APPLICATION_CONTROLLED_EXT failed as it did not have exlusive full-screen access. This may occur due to implementation-dependent reasons, outside of the application’s control."
        case vk.Result.ERROR_UNKNOWN:
            return !get_extended ? "VK_ERROR_UNKNOWN" : "VK_ERROR_UNKNOWN An unknown error has occurred either the application has provided invalid input, or an implementation failure has occurred."
    }
	return ""
}

/**
 * Inticates if the passed result is a success or an error as defined by the Vulkan spec.
 * @returns True if success otherwise false. Defaults to true for unknown result types.
 */
vulkan_result_is_success :: proc(result: vk.Result) -> bool {
	// From: https://www.khronos.org/registry/vulkan/specs/1.2-extensions/man/html/VkResult.html
    #partial switch (result) {
    	// Success Codes
        case vk.Result.SUCCESS:
        case vk.Result.NOT_READY:
        case vk.Result.TIMEOUT:
        case vk.Result.EVENT_SET:
        case vk.Result.EVENT_RESET:
        case vk.Result.INCOMPLETE:
        case vk.Result.SUBOPTIMAL_KHR:
        case vk.Result.THREAD_IDLE_KHR:
        case vk.Result.THREAD_DONE_KHR:
        case vk.Result.OPERATION_DEFERRED_KHR:
        case vk.Result.OPERATION_NOT_DEFERRED_KHR:
        case vk.Result.PIPELINE_COMPILE_REQUIRED_EXT:
            return true

        // Error codes
        case vk.Result.ERROR_OUT_OF_HOST_MEMORY:
        case vk.Result.ERROR_OUT_OF_DEVICE_MEMORY:
        case vk.Result.ERROR_INITIALIZATION_FAILED:
        case vk.Result.ERROR_DEVICE_LOST:
        case vk.Result.ERROR_MEMORY_MAP_FAILED:
        case vk.Result.ERROR_LAYER_NOT_PRESENT:
        case vk.Result.ERROR_EXTENSION_NOT_PRESENT:
        case vk.Result.ERROR_FEATURE_NOT_PRESENT:
        case vk.Result.ERROR_INCOMPATIBLE_DRIVER:
        case vk.Result.ERROR_TOO_MANY_OBJECTS:
        case vk.Result.ERROR_FORMAT_NOT_SUPPORTED:
        case vk.Result.ERROR_FRAGMENTED_POOL:
        case vk.Result.ERROR_SURFACE_LOST_KHR:
        case vk.Result.ERROR_NATIVE_WINDOW_IN_USE_KHR:
        case vk.Result.ERROR_OUT_OF_DATE_KHR:
        case vk.Result.ERROR_INCOMPATIBLE_DISPLAY_KHR:
        case vk.Result.ERROR_INVALID_SHADER_NV:
        case vk.Result.ERROR_OUT_OF_POOL_MEMORY:
        case vk.Result.ERROR_INVALID_EXTERNAL_HANDLE:
        case vk.Result.ERROR_FRAGMENTATION:
        case vk.Result.ERROR_INVALID_DEVICE_ADDRESS_EXT:
        // NOTE: Same as above
        //case vk.Result.ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS:
        case vk.Result.ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT:
        case vk.Result.ERROR_UNKNOWN:
            return false
    }
	return true
}
