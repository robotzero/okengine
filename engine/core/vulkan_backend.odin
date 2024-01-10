package core

import v "vendor:vulkan"
import "core:strings"

vulcan_context :: struct {
	instance: v.Instance,
	allocator: ^v.AllocationCallbacks,
}

// static Vulcan context
v_context : vulcan_context

vulkan_renderer_backend_initialize :: proc(backend: ^renderer_backend, application_name: string, plat_state: ^platform_state) -> bool {
	vulkan_proc_addr := platform_initialize_vulkan()
	//v.load_proc_addresses_global(vulkan_proc_addr)
	v.load_proc_addresses(vulkan_proc_addr)

 	// @TODO: custom allocator.
	v_context.allocator = nil

	// Setup vulkan instance
	app_info : v.ApplicationInfo = {
		sType = v.StructureType.APPLICATION_INFO,
		apiVersion = v.API_VERSION_1_2,
		pApplicationName = cstring("OK!"),
		applicationVersion = v.MAKE_VERSION(1, 0, 0),
		pEngineName = cstring("OK Engine"),
		engineVersion = v.MAKE_VERSION(1, 0, 0),
	}


	create_info : v.InstanceCreateInfo = {
		sType = v.StructureType.INSTANCE_CREATE_INFO,
		pApplicationInfo = &app_info,
		enabledExtensionCount = 0,
		ppEnabledExtensionNames = nil,
		enabledLayerCount = 0,
		ppEnabledLayerNames = nil,
	}

	result : v.Result = v.CreateInstance(&create_info, v_context.allocator, &v_context.instance)
	if result != v.Result.SUCCESS {
		log_error("vkCreateInstance failed with result: %u", result)
		return false
	}

	log_info("Vulkan renderer initialized successfully.")

	return true
}

vulkan_renderer_backend_shutdown :: proc(backend: ^renderer_backend) {
}

vulkan_renderer_backend_on_resized :: proc(backend: ^renderer_backend, width: u16, height: u16) {
}

vulkan_renderer_backend_begin_frame :: proc(backend: ^renderer_backend, delta_time: f32) -> bool {
    return true
}

vulkan_renderer_backend_end_frame :: proc(backend: ^renderer_backend, delta_time: f32) -> bool {
    return true
}
