package core

import "core:strings"
import "core:runtime"

import arr "../containers"
import vk "vendor:vulkan"

find_memory_index :: #type proc(type_filter: u32, property_flags: vk.MemoryPropertyFlags) -> i32

// static Vulkan context
v_context : vulkan_context
cached_framebuffer_width  : u32 = 0
cached_framebuffer_height : u32 = 0

vulkan_debug_callback :: proc "stdcall" (messageSeverity: vk.DebugUtilsMessageSeverityFlagEXT, messageTypes: vk.DebugUtilsMessageTypeFlagsEXT, pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT, pUserData: rawptr) -> b32 {
    context = runtime.default_context()
	switch messageSeverity {
		case vk.DebugUtilsMessageSeverityFlagEXT.ERROR: log_error(string(pCallbackData.pMessage))
		case vk.DebugUtilsMessageSeverityFlagEXT.WARNING: log_warning(string(pCallbackData.pMessage))
		case vk.DebugUtilsMessageSeverityFlagEXT.INFO: log_info(string(pCallbackData.pMessage))
		case vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE: log_debug(string(pCallbackData.pMessage))
	}
    return false
}

vulkan_renderer_backend_initialize :: proc(backend: ^renderer_backend, application_name: string, plat_state: ^platform_state) -> bool {
	vulkan_proc_addr := platform_initialize_vulkan()
	// vk.load_proc_addresses_global(vulkan_proc_addr)
	vk.load_proc_addresses(vulkan_proc_addr)

	// Function pointers
	v_context.find_memory_index_proc = find_memory_index_proc

 	// @TODO: custom allocator.
	v_context.allocator = nil

	application_get_framebuffer_size(&cached_framebuffer_width, &cached_framebuffer_height)
	v_context.framebuffer_width = cached_framebuffer_width != 0 ? cached_framebuffer_width : 800
	v_context.framebuffer_height = cached_framebuffer_height != 0 ? cached_framebuffer_height : 600
	cached_framebuffer_width = 0
	cached_framebuffer_height = 0

	required_extensions := arr.darray_create_default(cstring)
	arr.darray_push(&required_extensions, vk.KHR_SURFACE_EXTENSION_NAME)
	platform_get_required_extension_names(&required_extensions)
	required_validation_layer_names : [dynamic]cstring
	required_validation_layer_count : u32 = 0
	err : Error = Error.Okay
	available_layers : [dynamic]vk.LayerProperties
	defer arr.darray_destroy(available_layers)
	defer arr.darray_destroy(required_extensions)
	defer arr.darray_destroy(required_validation_layer_names)

	debug_setup :: proc(required_extensions: ^[dynamic]cstring) -> ([dynamic]cstring, u32, [dynamic]vk.LayerProperties, Error) {
		if ODIN_DEBUG == false {
			return nil, 0, nil, Error.Okay
		}
		arr.darray_push(required_extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
		log_debug("Required extensions:")
		for v, _ in required_extensions {
			log_debug(cast(string)v)
		}

		// If validation should be done, get a list of the required validation layer names
		// and make sure they exist. Validation layers should only be enabled on non-release builds.
		log_info("Validation layers enabled. Enumerating...")

		// The list of validation layers required.
		required_validation_layer_names : [dynamic]cstring = arr.darray_create_default(cstring)
		arr.darray_push(&required_validation_layer_names, "VK_LAYER_KHRONOS_validation")
		required_validation_layer_count := cast(u32)arr.darray_length(required_validation_layer_names)

		// Obtain a list of available validation layers
		available_layer_count : u32 = 0
		if ok := vk.EnumerateInstanceLayerProperties(&available_layer_count, nil); ok != vk.Result.SUCCESS {
			log_error("Failed to enumerate instance layer properties")
		}
		available_layers := arr.darray_create(cast(u64)available_layer_count, vk.LayerProperties)
		if ok:= vk.EnumerateInstanceLayerProperties(&available_layer_count, raw_data(available_layers)); ok != vk.Result.SUCCESS {
			log_error("Failed to enumerate instance layer properties")
		}

		// Verify all required layers are available
		outer: for layer_name, _ in required_validation_layer_names {
			for layer, _ in &available_layers {
				if layer_name == cstring(&layer.layerName[0]) do continue outer
			}

			log_fatal("Required validation layer is missing: %s", layer_name)
			return nil, 0, nil, Error.Missing_Validation_Layer
		}

		log_info("All required validation layers are present.")

		return required_validation_layer_names, required_validation_layer_count, available_layers, Error.Okay
	}

	required_validation_layer_names, required_validation_layer_count, available_layers, err = debug_setup(&required_extensions)
	if err == Error.Missing_Validation_Layer {
		return false
	}

	// Setup vulkan instance
	app_info : vk.ApplicationInfo = {
		sType = vk.StructureType.APPLICATION_INFO,
		apiVersion = vk.API_VERSION_1_3,
		pApplicationName = cstring("OK!"),
		applicationVersion = vk.MAKE_VERSION(1, 0, 0),
		pEngineName = cstring("OK Engine"),
		engineVersion = vk.MAKE_VERSION(1, 0, 0),
	}

	create_info : vk.InstanceCreateInfo = {
		sType = vk.StructureType.INSTANCE_CREATE_INFO,
		pApplicationInfo = &app_info,
		enabledExtensionCount = cast(u32)arr.darray_length(required_extensions),
		ppEnabledExtensionNames = &required_extensions[0],
		enabledLayerCount = cast(u32)arr.darray_length(required_validation_layer_names),
		ppEnabledLayerNames = &required_validation_layer_names[0],
	}

	result : vk.Result = vk.CreateInstance(&create_info, v_context.allocator, &v_context.instance)
	if result != vk.Result.SUCCESS {
		log_error("vkCreateInstance failed with result: %u", result)
		return false
	}

	create_debugger :: proc() -> Error {
		if ODIN_DEBUG == false {
			return Error.Okay
		}

		log_debug("Creating Vulkan debugger...")
		debug_create_info : vk.DebugUtilsMessengerCreateInfoEXT = {
			sType = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
			messageSeverity = { vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE, vk.DebugUtilsMessageSeverityFlagEXT.WARNING, vk.DebugUtilsMessageSeverityFlagEXT.ERROR, vk.DebugUtilsMessageSeverityFlagEXT.INFO },
			messageType = { vk.DebugUtilsMessageTypeFlagEXT.GENERAL, vk.DebugUtilsMessageTypeFlagEXT.VALIDATION, vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE },
			pfnUserCallback = cast(vk.ProcDebugUtilsMessengerCallbackEXT)rawptr(vulkan_debug_callback),
			pUserData = nil,
		}
		vk.CreateDebugUtilsMessengerEXT = auto_cast vk.GetInstanceProcAddr(v_context.instance, cstring("vkCreateDebugUtilsMessengerEXT"))
		if vk.CreateDebugUtilsMessengerEXT == nil {
			return Error.Create_Debugger_Fail
		}
		res := vk.CreateDebugUtilsMessengerEXT(v_context.instance, &debug_create_info, v_context.allocator, &v_context.debug_messenger)
		if res != vk.Result.SUCCESS {
			return Error.Create_Debugger_Fail
		}

		//send debug message
  //       msg_callback_data : vk.DebugUtilsMessengerCallbackDataEXT = {
  //       	vk.StructureType.DEBUG_UTILS_MESSENGER_CALLBACK_DATA_EXT,
  //       	nil, {}, nil, 0, "test message", 0, nil, 0, nil, 0, nil,
  //     	}
	 //  	vk.SubmitDebugUtilsMessageEXT = auto_cast vk.GetInstanceProcAddr(v_context.instance, cstring("vkSubmitDebugUtilsMessageEXT"))
  //     	vk.SubmitDebugUtilsMessageEXT(v_context.instance, {vk.DebugUtilsMessageSeverityFlagEXT.WARNING}, {vk.DebugUtilsMessageTypeFlagEXT.GENERAL}, &msg_callback_data);

		// log_debug("%s", msg_callback_data.pMessage)
      	log_debug("Vulkan debugger created.")
		
		return Error.Okay
	}

	if err := create_debugger(); err == Error.Create_Debugger_Fail {
		return false
	}

	log_debug("Creating Vulkan surface...")
	if platform_create_vulkan_surface(plat_state, &v_context) == false {
		log_error("Failed to create platform surface")
		return false
	}
	log_debug("Vulkan surface created.")

	if vulkan_device_create(&v_context) == false {
		log_error("Failed to create device!")
		return false
	}

	// Swapchain
	vulkan_swapchain_create(&v_context, v_context.framebuffer_width, v_context.framebuffer_height, &v_context.swapchain)

	vulkan_renderpass_create(&v_context, &v_context.main_renderpass, 0, 0, cast(f32)v_context.framebuffer_width, cast(f32)v_context.framebuffer_height, 0.0, 0.0, 0.2, 1.0, 1.0, 0)

	// Swapchain framebuffers.
	v_context.swapchain.framebuffers = arr.darray_create(v_context.swapchain.image_count, vulkan_framebuffer)
	regenerate_framebuffers(backend, &v_context.swapchain, &v_context.main_renderpass)

	// Create command buffers.
	create_command_buffers(backend)

	// Create sync object.
	v_context.image_available_semaphores = arr.darray_create(v_context.swapchain.max_frames_in_flight, vk.Semaphore)
	v_context.queue_complete_semaphores = arr.darray_create(v_context.swapchain.max_frames_in_flight, vk.Semaphore)
	v_context.in_flight_fences = arr.darray_create(v_context.swapchain.max_frames_in_flight, vulkan_fence)

	for i in 0..<v_context.swapchain.max_frames_in_flight {
		semaphore_create_info : vk.SemaphoreCreateInfo = {
			sType = vk.StructureType.SEMAPHORE_CREATE_INFO,
		}

		vk.CreateSemaphore(v_context.device.logical_device, &semaphore_create_info, v_context.allocator, &v_context.image_available_semaphores[i])
		vk.CreateSemaphore(v_context.device.logical_device, &semaphore_create_info, v_context.allocator, &v_context.queue_complete_semaphores[i])

		// Crete the fence in signaled state, indicating that the first frame has already been "rendered".
		// This will prevent the application from waiting indefinitely for the first frame to render since
		// it cannot be rendered until a frame is "rendered" before it.
		vulkan_fence_create(&v_context, true, &v_context.in_flight_fences[i])
	}

	// In flight fences should not yet exist at this point, so clear the list. These are stored in pointers
	// because the initial state should be 0, and will be 0 when not in use. Actual fences are not owned
	// by this list.
	v_context.images_in_flight = arr.darray_create(v_context.swapchain.image_count, vulkan_fence)
	for i in 0..<v_context.swapchain_image_count {
		v_context.images_in_flight[i] = 0
	}

	log_info("Vulkan renderer initialized successfully.")

	return true
}

vulkan_renderer_backend_shutdown :: proc(backend: ^renderer_backend) {
	vk.DeviceWaitIdle(v_context.device.logical_device)
	// Destroy is the opposide order of creation.

	// Sync objects
	for i in 0..<v_context.swapchain.max_frames_in_flight {
		if v_context.image_available_semaphores[i] != nil {
			vk.DestroySemaphore(v_context.device.logical_device, v_context.image_available_semaphores[i], v_context.allocator)
			v_context.image_available_semaphores[i] = 0
		}
		if v_context.queue_complete_semaphores[i] != nil {
			vk.DestroySemaphore(v_context.device.logical_device, v_context.queue_complete_semaphores[i], v_context.allocator)
			v_context.queue_complete_semaphores[i] = 0
		}
		vulkan_fence_destroy(&v_context, &v_context.in_flight_fences[i])
	}
	arr.darray_destroy(v_context.image_available_semaphores)
	v_context.image_available_semaphores = 0

	arr.darray_destroy(v_context.queue_complete_semaphores)
	v_context.queue_complete_semaphores = 0

	arr.darray_destroy(v_context.in_flight.fences)
	v_context.in_flight_fences = 0

	arr.darray_destroy(v_context.images_in_flight)
	v_context.images_in_flight = 0
	
	// Command buffers
	for i in 0..<v_context.swapchain.image_count {
		if v_context.graphics_command_buffers[i].handle != nil {
			vulkan_command_buffer_free(&v_context, v_context.device.graphics_command_pool, &v_context.graphics_command_buffers[i])
			v_context.graphics_command_buffers[i].handle = nil
		}
	}
	arr.darray_destroy(v_context.graphics_command_buffers)
	v_context.graphics_command_buffers = nil

	for i in 0..<v_context.swapchain.image_count {
		vulkan_framebuffer_destroy(&v_context, &v_context.swapchain.framebuffers[i])
	}

	// Renderpass
	vulkan_renderpass_destroy(&v_context, &v_context.main_renderpass)

	// Swapchain
	vulkan_swapchain_destroy(&v_context, &v_context.swapchain)

	log_debug("Destroying Vulkan device...")
	vulkan_device_destroy(&v_context)

	log_debug("Destroying Vulkan surface...")
	if v_context.surface != 0 {
		vk.DestroySurfaceKHR(v_context.instance, v_context.surface, v_context.allocator)
		v_context.surface = 0
	}

	if ODIN_DEBUG {
		if v_context.debug_messenger != 0 {
			vk.DestroyDebugUtilsMessengerEXT = auto_cast vk.GetInstanceProcAddr(v_context.instance, cstring("vkDestroyDebugUtilsMessengerEXT"))
			if vk.DestroyDebugUtilsMessengerEXT != nil {
				vk.DestroyDebugUtilsMessengerEXT(v_context.instance, v_context.debug_messenger, v_context.allocator)
				log_debug("Destroying Vulkan debugger...")
			}
		}
	}

	if v_context.instance != nil {
		log_debug("Destroying Vulkan instance...")
		vk.DestroyInstance(v_context.instance, v_context.allocator)
	}
}

vulkan_renderer_backend_on_resized :: proc(backend: ^renderer_backend, width: u16, height: u16) {
}

vulkan_renderer_backend_begin_frame :: proc(backend: ^renderer_backend, delta_time: f32) -> bool {
    return true
}

vulkan_renderer_backend_end_frame :: proc(backend: ^renderer_backend, delta_time: f32) -> bool {
    return true
}

find_memory_index_proc :: proc(type_filter: u32, property_flags: vk.MemoryPropertyFlags) -> i32 {
	memory_properties : vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(v_context.device.physical_device, &memory_properties)

	for i in 0..<memory_properties.memoryTypeCount {
		// Check each memory type to see if its bit is set to 1
		if (type_filter & (1 << i) != 0) && (memory_properties.memoryTypes[i].propertyFlags & property_flags) == property_flags {
			return cast(i32)i;
		}
	}
	log_warning("Unable to find suitable memory type!")

	return -1
}

create_command_buffers :: proc(backend: ^renderer_backend) {
	if v_context.graphics_command_buffers == nil {
		v_context.graphics_command_buffers = arr.darray_create(cast(u64)v_context.swapchain.image_count, vulkan_command_buffer)
	}

	for i in 0..<v_context.swapchain.image_count {
		if v_context.graphics_command_buffers[i].handle != nil {
			vulkan_command_buffer_free(&v_context, v_context.device.graphics_command_pool, &v_context.graphics_command_buffers[i])
		}

		v_context.graphics_command_buffers[i] = {}

		vulkan_command_buffer_allocate(
			&v_context,
			v_context.device.graphics_command_pool,
			true,
			&v_context.graphics_command_buffers[i],
		)
	}

	log_debug("Vulkan command buffers created.")
}

regenerate_framebuffers :: proc(backend: ^renderer_backend, swapchain: ^vulkan_swapchain, renderpass: ^vulkan_renderpass) {
	for i in 0..<swapchain.image_count {
		// TODO: make this dynamic based on the ucrrently configured attachments
		attachment_count : u32 = 2
		attachments : [?]vk.ImageView = {swapchain.views[i], swapchain.depth_attachment.view}

		vulkan_framebuffer_create(&v_context, renderpass, v_context.framebuffer_width, v_context.framebuffer_height, attachment_count, attachments, &v_context.swapchain.framebuffers[i])
	}
}
