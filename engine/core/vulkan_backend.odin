package core

import v "vendor:vulkan"

vulcan_context :: struct {
	instance: v.Instance,
	allocator: ^v.AllocationCallbacks,
}

// static Vulcan context
v_context : vulcan_context

vulkan_renderer_backend_initialize :: proc(backend: ^renderer_backend, application_name: string, plat_state: ^renderer_platform_state) -> bool {
 	// @TODO: custom allocator.
	v_context.allocator = nil

	// Setup vulkan instance
	app_info : v.ApplicationInfo = {}
	app_info.sType = v.StructureType.APPLICATION_INFO
	app_info.pApplicationName = "blah";
    app_info.applicationVersion = v.MAKE_VERSION(1, 0, 0);
    app_info.pEngineName = "OK Engine";
    app_info.engineVersion = v.MAKE_VERSION(1, 0, 0);

	create_info : v.InstanceCreateInfo = {}
	create_info.sType = v.StructureType.INSTANCE_CREATE_INFO
	create_info.pApplicationInfo = &app_info
	create_info.enabledExtensionCount = 0
	create_info.ppEnabledExtensionNames = nil
	create_info.enabledLayerCount = 0
	create_info.ppEnabledLayerNames = nil

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
