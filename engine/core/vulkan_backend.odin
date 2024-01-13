package core

import "core:strings"
import "core:runtime"

import arr "../containers"
import vk "vendor:vulkan"

when ODIN_DEBUG == true {
	vulcan_context :: struct {
		instance: vk.Instance,
		allocator: ^vk.AllocationCallbacks,
		debug_messenger: vk.DebugUtilsMessengerEXT,
	}
} else {
	vulcan_context :: struct {
		instance: vk.Instance,
		allocator: ^vk.AllocationCallbacks,
	}
}

// static Vulcan context
v_context : vulcan_context

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

 	// @TODO: custom allocator.
	v_context.allocator = nil

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

	log_info("Vulkan renderer initialized successfully.")

	return true
}

vulkan_renderer_backend_shutdown :: proc(backend: ^renderer_backend) {
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
		vk.DestroyInstance = auto_cast vk.GetInstanceProcAddr(v_context.instance, cstring("vkDestroyInstance"))
		if vk.DestroyInstance != nil {
			vk.DestroyInstance(v_context.instance, v_context.allocator)
			log_debug("Destroying Vulkan instance...")
		}
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
