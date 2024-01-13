package core

import vk "vendor:vulkan"
import "core:strings"
import arr "../containers"
import "core:runtime"

vulcan_context :: struct {
	instance: vk.Instance,
	allocator: ^vk.AllocationCallbacks,
}

// static Vulcan context
v_context : vulcan_context
vulkan_debug_callback :: proc "stdcall" (messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT, messageTypes: vk.DebugUtilsMessageTypeFlagsEXT, pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT, pUserData: rawptr) -> b32 {
    context = runtime.default_context()
    log_debug("validation layer: %s", pCallbackData.pMessage)
// 	 if .ERROR in messageSeverity
//   {
//       fmt.eprintln("VULKAN ERROR!!!! : ", pCallbackData.pMessage);
//   }
//   if .WARNING in messageSeverity
//   {
//       fmt.eprintln("VULKAN WARNING!!!! : ", pCallbackData.pMessage);
//   }
//   else
//   {
//     // fmt.eprintln("Vk validation layer: ", pCallbackData.pMessage);
//   }
//   return false;
// }
    return false
}

vulkan_renderer_backend_initialize :: proc(backend: ^renderer_backend, application_name: string, plat_state: ^platform_state) -> bool {
	vulkan_proc_addr := platform_initialize_vulkan()
	//v.load_proc_addresses_global(vulkan_proc_addr)
	vk.load_proc_addresses(vulkan_proc_addr)

 	// @TODO: custom allocator.
	v_context.allocator = nil

	required_extensions := arr.darray_create_default(cstring)
	arr.darray_push(&required_extensions, vk.KHR_SURFACE_EXTENSION_NAME)
	platform_get_required_extension_names(&required_extensions)
	required_validation_layer_names : [dynamic]cstring = nil
	required_validation_layer_count : u32 = 0
	err : Error = Error.Okay

	debug_setup :: proc(required_extensions: ^[dynamic]cstring) -> ([dynamic]cstring, u32, Error) {
		if ODIN_DEBUG == false {
			return nil, 0, Error.Okay
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
		required_validation_layer_names := arr.darray_create_default(cstring)
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
			log_info("Searching for layer: %s...", layer_name)
			log_debug("L %v ", layer_name)
			for layer, _ in &available_layers {
				log_debug("B %s", cstring(&layer.layerName[0]))
				if layer_name == cstring(&layer.layerName[0]) do continue outer
			}

			log_fatal("Required validation layer is missing: %s", layer_name)
			return nil, 0, Error.Missing_Validation_Layer
		}

		log_info("All required validation layers are present.")

		return required_validation_layer_names, required_validation_layer_count, Error.Okay
	}

	required_validation_layer_names, required_validation_layer_count, err = debug_setup(&required_extensions)
	if err == Error.Missing_Validation_Layer {
		return false
	}


	// Setup vulkan instance
	app_info : vk.ApplicationInfo = {
		sType = vk.StructureType.APPLICATION_INFO,
		apiVersion = vk.API_VERSION_1_2,
		pApplicationName = cstring("OK!"),
		applicationVersion = vk.MAKE_VERSION(1, 0, 0),
		pEngineName = cstring("OK Engine"),
		engineVersion = vk.MAKE_VERSION(1, 0, 0),
	}

	create_info : vk.InstanceCreateInfo = {
		sType = vk.StructureType.INSTANCE_CREATE_INFO,
		pApplicationInfo = &app_info,
		enabledExtensionCount = 0,
		ppEnabledExtensionNames = &required_extensions[0],
		enabledLayerCount = cast(u32)arr.darray_length(required_extensions),
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
			messageType = {vk.DebugUtilsMessageTypeFlagEXT.GENERAL, vk.DebugUtilsMessageTypeFlagEXT.VALIDATION, vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE },
			pfnUserCallback = cast(vk.ProcDebugUtilsMessengerCallbackEXT)vulkan_debug_callback,
			pUserData = nil,
		}
		vk_debug_messenger : vk.DebugUtilsMessengerEXT;

		res := vk.CreateDebugUtilsMessengerEXT(v_context.instance, &debug_create_info, nil, &vk_debug_messenger);
      	if res != vk.Result.SUCCESS {
			return Error.Create_Debugger_Fail
		}

		  //send debug message
      //    msg_callback_data : vk.DebugUtilsMessengerCallbackDataEXT = {
      //   .DEBUG_UTILS_MESSENGER_CALLBACK_DATA_EXT,
      //   nil, {}, nil, 0, "test message", 0, nil, 0, nil, 0, nil,
      // }
      // vk.SubmitDebugUtilsMessageEXT(vk_instance, {.WARNING}, {.GENERAL}, &msg_callback_data);

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
}

vulkan_renderer_backend_on_resized :: proc(backend: ^renderer_backend, width: u16, height: u16) {
}

vulkan_renderer_backend_begin_frame :: proc(backend: ^renderer_backend, delta_time: f32) -> bool {
    return true
}

vulkan_renderer_backend_end_frame :: proc(backend: ^renderer_backend, delta_time: f32) -> bool {
    return true
}
