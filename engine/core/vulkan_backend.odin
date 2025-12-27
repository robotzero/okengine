#+feature dynamic-literals
package core

import "../okmath"
import "base:runtime"
import "core:c"
import "core:strings"

import arr "../containers"
import vk "vendor:vulkan"

find_memory_index :: #type proc(type_filter: u32, property_flags: vk.MemoryPropertyFlags) -> i32

// static Vulkan context
@(private = "file")
v_context: vulkan_context
@(private = "file")
cached_framebuffer_width: u32 = 0
@(private = "file")
cached_framebuffer_height: u32 = 0

vulkan_debug_callback :: proc "stdcall" (
	messageSeverity: vk.DebugUtilsMessageSeverityFlagEXT,
	messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
	pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> b32 {
	context = runtime.default_context()
	switch messageSeverity {
	case vk.DebugUtilsMessageSeverityFlagEXT.ERROR:
		log_error(string(pCallbackData.pMessage))
	case vk.DebugUtilsMessageSeverityFlagEXT.WARNING:
		log_warning(string(pCallbackData.pMessage))
	case vk.DebugUtilsMessageSeverityFlagEXT.INFO:
		log_info(string(pCallbackData.pMessage))
	case vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE:
		log_debug(string(pCallbackData.pMessage))
	}
	return false
}

vulkan_renderer_backend_initialize :: proc(
	backend: ^renderer_backend,
	application_name: string,
) -> bool {
	vulkan_proc_addr := platform_initialize_vulkan()
	vk.load_proc_addresses_global(vulkan_proc_addr)
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
	required_validation_layer_names: [dynamic]cstring
	required_validation_layer_count: u32 = 0
	err: Error = Error.Okay
	available_layers: [dynamic]vk.LayerProperties
	defer arr.darray_destroy(available_layers)
	defer arr.darray_destroy(required_extensions)
	defer arr.darray_destroy(required_validation_layer_names)

	debug_setup :: proc(
		required_extensions: ^[dynamic]cstring,
	) -> (
		[dynamic]cstring,
		u32,
		[dynamic]vk.LayerProperties,
		Error,
	) {
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
		required_validation_layer_names: [dynamic]cstring = arr.darray_create_default(cstring)
		arr.darray_push(&required_validation_layer_names, "VK_LAYER_KHRONOS_validation")
		required_validation_layer_count := cast(u32)arr.darray_length(
			required_validation_layer_names,
		)

		// Obtain a list of available validation layers
		available_layer_count: u32 = 0
		if ok := vk.EnumerateInstanceLayerProperties(&available_layer_count, nil);
		   ok != vk.Result.SUCCESS {
			log_error("Failed to enumerate instance layer properties")
		}
		available_layers := arr.darray_create(cast(u64)available_layer_count, vk.LayerProperties)
		if ok := vk.EnumerateInstanceLayerProperties(
			&available_layer_count,
			raw_data(available_layers),
		); ok != vk.Result.SUCCESS {
			log_error("Failed to enumerate instance layer properties")
		}

		// Verify all required layers are available
		outer: for layer_name, _ in required_validation_layer_names {
			for &layer, _ in available_layers {
				if layer_name == cstring(&layer.layerName[0]) do continue outer
			}

			log_fatal("Required validation layer is missing: %s", layer_name)
			return nil, 0, nil, Error.Missing_Validation_Layer
		}

		log_info("All required validation layers are present.")

		return required_validation_layer_names,
			required_validation_layer_count,
			available_layers,
			Error.Okay
	}

	required_validation_layer_names, required_validation_layer_count, available_layers, err =
		debug_setup(&required_extensions)
	if err == Error.Missing_Validation_Layer {
		return false
	}

	// Setup vulkan instance
	app_info: vk.ApplicationInfo = {
			sType              = vk.StructureType.APPLICATION_INFO,
			apiVersion         = vk.API_VERSION_1_3,
			pApplicationName   = cstring("OK!"),
			applicationVersion = vk.MAKE_VERSION(1, 0, 0),
			pEngineName        = cstring("OK Engine"),
			engineVersion      = vk.MAKE_VERSION(1, 0, 0),
		}

	create_info: vk.InstanceCreateInfo = {
			sType                   = vk.StructureType.INSTANCE_CREATE_INFO,
			pApplicationInfo        = &app_info,
			enabledExtensionCount   = cast(u32)arr.darray_length(required_extensions),
			ppEnabledExtensionNames = &required_extensions[0],
			enabledLayerCount       = cast(u32)arr.darray_length(required_validation_layer_names),
			ppEnabledLayerNames     = &required_validation_layer_names[0],
		}

	result: vk.Result = vk.CreateInstance(&create_info, v_context.allocator, &v_context.instance)
	if result != vk.Result.SUCCESS {
		log_error("vkCreateInstance failed with result: %u", result)
		return false
	}

	when ODIN_DEBUG == true {
		create_debugger :: proc() -> Error {
			log_debug("Creating Vulkan debugger...")
			debug_create_info: vk.DebugUtilsMessengerCreateInfoEXT = {
					sType           = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
					messageSeverity = {
						vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE,
						vk.DebugUtilsMessageSeverityFlagEXT.WARNING,
						vk.DebugUtilsMessageSeverityFlagEXT.ERROR,
						vk.DebugUtilsMessageSeverityFlagEXT.INFO,
					},
					messageType     = {
						vk.DebugUtilsMessageTypeFlagEXT.GENERAL,
						vk.DebugUtilsMessageTypeFlagEXT.VALIDATION,
						vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE,
					},
					pfnUserCallback = cast(vk.ProcDebugUtilsMessengerCallbackEXT)rawptr(vulkan_debug_callback),
					pUserData       = nil,
				}
			vk.CreateDebugUtilsMessengerEXT =
			auto_cast vk.GetInstanceProcAddr(
				v_context.instance,
				cstring("vkCreateDebugUtilsMessengerEXT"),
			)
			if vk.CreateDebugUtilsMessengerEXT == nil {
				return Error.Create_Debugger_Fail
			}
			res := vk.CreateDebugUtilsMessengerEXT(
				v_context.instance,
				&debug_create_info,
				v_context.allocator,
				&v_context.debug_messenger.debug_messenger,
			)
			if res != vk.Result.SUCCESS {
				return Error.Create_Debugger_Fail
			}

			//send debug message
			//msg_callback_data : vk.DebugUtilsMessengerCallbackDataEXT = {
			//vk.StructureType.DEBUG_UTILS_MESSENGER_CALLBACK_DATA_EXT,
			//nil, {}, nil, 0, "test message", 0, nil, 0, nil, 0, nil,
			//}
			//vk.SubmitDebugUtilsMessageEXT = auto_cast vk.GetInstanceProcAddr(v_context.instance, cstring("vkSubmitDebugUtilsMessageEXT"))
			//vk.SubmitDebugUtilsMessageEXT(v_context.instance, {vk.DebugUtilsMessageSeverityFlagEXT.WARNING}, {vk.DebugUtilsMessageTypeFlagEXT.GENERAL}, &msg_callback_data);

			// log_debug("%s", msg_callback_data.pMessage)
			log_debug("Vulkan debugger created.")

			return Error.Okay
		}

		if err := create_debugger(); err == Error.Create_Debugger_Fail {
			return false
		}
	}

	log_debug("Creating Vulkan surface...")
	if platform_create_vulkan_surface(&v_context) == false {
		log_error("Failed to create platform surface")
		return false
	}
	log_debug("Vulkan surface created.")

	if vulkan_device_create(&v_context) == false {
		log_error("Failed to create device!")
		return false
	}

	// Swapchain
	vulkan_swapchain_create(
		&v_context,
		v_context.framebuffer_width,
		v_context.framebuffer_height,
		&v_context.swapchain,
	)

	vulkan_renderpass_create(
		&v_context,
		&v_context.main_renderpass,
		0,
		0,
		cast(f32)v_context.framebuffer_width,
		cast(f32)v_context.framebuffer_height,
		0.0,
		0.0,
		0.2,
		1.0,
		1.0,
		0,
	)

	// Swapchain framebuffers.
	v_context.swapchain.framebuffers = arr.darray_create(
		cast(u64)v_context.swapchain.image_count,
		vulkan_framebuffer,
	)
	regenerate_framebuffers(backend, &v_context.swapchain, &v_context.main_renderpass)

	// Create command buffers.
	create_command_buffers(backend)

	// Create sync object.
	v_context.image_available_semaphores = arr.darray_create(
		cast(u64)v_context.swapchain.max_frames_in_flight,
		vk.Semaphore,
	)
	v_context.queue_complete_semaphores = arr.darray_create(
		cast(u64)v_context.swapchain.max_frames_in_flight,
		vk.Semaphore,
	)
	v_context.in_flight_fences = arr.darray_create(
		cast(u64)v_context.swapchain.max_frames_in_flight,
		vulkan_fence,
	)

	for i in 0 ..< v_context.swapchain.max_frames_in_flight {
		semaphore_create_info: vk.SemaphoreCreateInfo = {
			sType = vk.StructureType.SEMAPHORE_CREATE_INFO,
		}

		vk.CreateSemaphore(
			v_context.device.logical_device,
			&semaphore_create_info,
			v_context.allocator,
			&v_context.image_available_semaphores[i],
		)
		vk.CreateSemaphore(
			v_context.device.logical_device,
			&semaphore_create_info,
			v_context.allocator,
			&v_context.queue_complete_semaphores[i],
		)

		// Crete the fence in signaled state, indicating that the first frame has already been "rendered".
		// This will prevent the application from waiting indefinitely for the first frame to render since
		// it cannot be rendered until a frame is "rendered" before it.
		vulkan_fence_create(&v_context, true, &v_context.in_flight_fences[i])
	}

	// In flight fences should not yet exist at this point, so clear the list. These are stored in pointers
	// because the initial state should be 0, and will be 0 when not in use. Actual fences are not owned
	// by this list.
	v_context.images_in_flight = arr.darray_create(
		cast(u64)v_context.swapchain.image_count,
		^vulkan_fence,
	)
	for i in 0 ..< v_context.swapchain.image_count {
		v_context.images_in_flight[i] = nil
	}

	// Create buildin shaders
	if !vulkan_object_shader_create(&v_context, &v_context.object_shader) {
		log_error("Error loading built-in basic_lighting shader")
		return false
	}

	create_buffers(&v_context)

	// TODO: temporary code

	vert_count :: 4
	verts: [vert_count]okmath.vertex_3d

	verts[0].position.x = 0.0
	verts[0].position.y = -0.5
	verts[1].position.x = 0.5
	verts[1].position.y = 0.5
	verts[2].position.x = 0.0
	verts[2].position.y = 0.5
	verts[3].position.x = 0.5
	verts[3].position.y = -0.5

	index_count :: 6
	indices: [index_count]u32 = {0, 1, 2, 0, 3, 1}

	upload_data_range(
		&v_context,
		v_context.device.graphics_command_pool,
		0,
		v_context.device.graphics_queue,
		&v_context.object_vertex_buffer,
		0,
		size_of(okmath.vertex_3d) * vert_count,
		raw_data(verts[:]),
	)
	upload_data_range(
		&v_context,
		v_context.device.graphics_command_pool,
		0,
		v_context.device.graphics_queue,
		&v_context.object_index_buffer,
		0,
		size_of(u32) * index_count,
		raw_data(indices[:]),
	)

	log_info("Vulkan renderer initialized successfully.")

	return true
}

vulkan_renderer_backend_shutdown :: proc(backend: ^renderer_backend) {
	vk.DeviceWaitIdle(v_context.device.logical_device)
	// Destroy is the opposide order of creation.
	vulkan_buffer_destroy(&v_context, &v_context.object_vertex_buffer)
	vulkan_buffer_destroy(&v_context, &v_context.object_index_buffer)
	vulkan_object_shader_destroy(&v_context, &v_context.object_shader)

	// Sync objects
	for i in 0 ..< v_context.swapchain.max_frames_in_flight {
		if v_context.image_available_semaphores[i] != 0 {
			vk.DestroySemaphore(
				v_context.device.logical_device,
				v_context.image_available_semaphores[i],
				v_context.allocator,
			)
			v_context.image_available_semaphores[i] = 0
		}
		if v_context.queue_complete_semaphores[i] != 0 {
			vk.DestroySemaphore(
				v_context.device.logical_device,
				v_context.queue_complete_semaphores[i],
				v_context.allocator,
			)
			v_context.queue_complete_semaphores[i] = 0
		}
		vulkan_fence_destroy(&v_context, &v_context.in_flight_fences[i])
	}
	arr.darray_destroy(v_context.image_available_semaphores)
	v_context.image_available_semaphores = nil

	arr.darray_destroy(v_context.queue_complete_semaphores)
	v_context.queue_complete_semaphores = nil

	arr.darray_destroy(v_context.in_flight_fences)
	v_context.in_flight_fences = nil

	arr.darray_destroy(v_context.images_in_flight)
	v_context.images_in_flight = nil

	// Command buffers
	for i in 0 ..< v_context.swapchain.image_count {
		if v_context.graphics_command_buffers[i].handle != nil {
			vulkan_command_buffer_free(
				&v_context,
				v_context.device.graphics_command_pool,
				&v_context.graphics_command_buffers[i],
			)
			v_context.graphics_command_buffers[i].handle = nil
		}
	}
	arr.darray_destroy(v_context.graphics_command_buffers)
	v_context.graphics_command_buffers = nil

	for i in 0 ..< v_context.swapchain.image_count {
		vulkan_framebuffer_destroy(&v_context, &v_context.swapchain.framebuffers[i])
	}
	arr.darray_destroy(v_context.swapchain.framebuffers)
	delete(v_context.swapchain.images)
	delete(v_context.swapchain.views)

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

	when ODIN_DEBUG == true {
		if v_context.debug_messenger.debug_messenger != 0 {
			vk.DestroyDebugUtilsMessengerEXT =
			auto_cast vk.GetInstanceProcAddr(
				v_context.instance,
				cstring("vkDestroyDebugUtilsMessengerEXT"),
			)
			if vk.DestroyDebugUtilsMessengerEXT != nil {
				vk.DestroyDebugUtilsMessengerEXT(
					v_context.instance,
					v_context.debug_messenger.debug_messenger,
					v_context.allocator,
				)
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
	// Update the "framebuffer size generation", a counter which indicates when the
	// framebuffer size has been updated.
	cached_framebuffer_width = cast(u32)width
	cached_framebuffer_height = cast(u32)height
	v_context.framebuffer_size_generation = v_context.framebuffer_size_generation + 1

	log_info(
		"Vulkan renderer backend->resized: w/g/gen: %i/%i/%v",
		width,
		height,
		v_context.framebuffer_size_generation,
	)
}

vulkan_renderer_backend_begin_frame :: proc(backend: ^renderer_backend, delta_time: f32) -> bool {
	device: ^vulkan_device = &v_context.device

	// Check if recreating swap chain and boot out.
	if v_context.recreating_swapchain {
		result := vk.DeviceWaitIdle(device.logical_device)

		if !vulkan_result_is_success(result) {
			log_error(
				"vulkan renderer backend begin frame vkDeviceWaitIdle (1), failed: '%s'",
				vulkan_result_string(result, true),
			)
			return false
		}

		log_info("Recreating swapchain, booting")
		return false
	}

	// Check if the framebuffer has been resized. If so, a new swapchain must be created.
	if v_context.framebuffer_size_generation != v_context.framebuffer_size_last_generation {
		result := vk.DeviceWaitIdle(device.logical_device)

		if !vulkan_result_is_success(result) {
			log_error(
				"vulkan renderer backend begin frame vkDeviceWaitIdle (2), failed: '%s'",
				vulkan_result_string(result, true),
			)
			return false
		}

		// If the swapchain recreation failed (because, for example, the window was minimized),
		// boot out before unsetting the flag.
		if recreate_swapchain(backend) == false {
			return false
		}

		log_info("Resized, booting")
		return false
	}

	// Wait for the execution of the current frame to complete. The fence being free will allow this one to move on.
	if vulkan_fence_wait(
		   &v_context,
		   &v_context.in_flight_fences[v_context.current_frame],
		   max(u64),
	   ) ==
	   false {
		log_warning("In-flight fence wait failure!")
		return false
	}
	// Acquire the next image from the swap chain. Pass along the semaphore that should signaled when this completes.
	// This same semaphore will later be waited on by the queue submission to ensure this image is available.
	if (!vulkan_swapchain_acquire_next_image_index(
			   &v_context,
			   &v_context.swapchain,
			   max(u64),
			   v_context.image_available_semaphores[v_context.current_frame],
			   {},
			   &v_context.image_index,
		   )) {
		return false
	}

	// Begin recording commands.
	command_buffer: ^vulkan_command_buffer = &v_context.graphics_command_buffers[v_context.image_index]
	vulkan_command_buffer_reset(command_buffer)
	vulkan_command_buffer_begin(command_buffer, false, false, false)

	// Dynamic state
	viewport: vk.Viewport = {}
	viewport.x = 0.0
	viewport.y = cast(f32)v_context.framebuffer_height
	viewport.width = cast(f32)v_context.framebuffer_width
	viewport.height = -cast(f32)v_context.framebuffer_height
	viewport.minDepth = 0.0
	viewport.maxDepth = 1.0

	// Scissor
	scissor: vk.Rect2D = {}
	scissor.offset.x = 0
	scissor.offset.y = 0
	scissor.extent.width = v_context.framebuffer_width
	scissor.extent.height = v_context.framebuffer_height

	vk.CmdSetViewport(command_buffer.handle, 0, 1, &viewport)
	vk.CmdSetScissor(command_buffer.handle, 0, 1, &scissor)

	v_context.main_renderpass.w = cast(f32)v_context.framebuffer_width
	v_context.main_renderpass.h = cast(f32)v_context.framebuffer_height

	// Begin the render pass.
	vulkan_renderpass_begin(
		command_buffer,
		&v_context.main_renderpass,
		v_context.swapchain.framebuffers[v_context.image_index].handle,
	)
	// TODO: temporary

	vulkan_object_shader_use(&v_context, &v_context.object_shader)

	// Bind vertex buffer at offset

	offsets: [1]vk.DeviceSize = {0}
	vk.CmdBindVertexBuffers(
		command_buffer.handle,
		0,
		1,
		&v_context.object_vertex_buffer.handle,
		&offsets[0],
	)

	// Bind index buffer at offset
	vk.CmdBindIndexBuffer(
		command_buffer.handle,
		v_context.object_index_buffer.handle,
		0,
		vk.IndexType.UINT32,
	)

	// Issue the draw.
	vk.CmdDrawIndexed(command_buffer.handle, 6, 1, 0, 0, 0)

	return true
}

vulkan_renderer_backend_end_frame :: proc(backend: ^renderer_backend, delta_time: f32) -> bool {
	command_buffer: ^vulkan_command_buffer = &v_context.graphics_command_buffers[v_context.image_index]

	// End renderpass
	vulkan_renderpass_end(command_buffer, &v_context.main_renderpass)

	vulkan_command_buffer_end(command_buffer)

	// Make sure the previous frame is not using this image (i.e. its fence is being waited on)
	if (v_context.images_in_flight[v_context.image_index] != nil) { 	// was frame
		vulkan_fence_wait(
			&v_context,
			v_context.images_in_flight[v_context.image_index],
			c.UINT64_MAX,
		)
	}

	// Mark the image fence as in-use by this frame.
	v_context.images_in_flight[v_context.image_index] =
	&v_context.in_flight_fences[v_context.current_frame]

	// Reset the fence for use on the next frame
	vulkan_fence_reset(&v_context, &v_context.in_flight_fences[v_context.current_frame])

	// Submit the queue and wait for the operation to complete.
	// Begin queue submission
	submit_info: vk.SubmitInfo = {
		sType = vk.StructureType.SUBMIT_INFO,
	}

	// Command buffer(s) to be executed.
	submit_info.commandBufferCount = 1
	submit_info.pCommandBuffers = &command_buffer.handle

	// The semaphore(s) to be signaled when the queue is complete.
	submit_info.signalSemaphoreCount = 1
	submit_info.pSignalSemaphores = &v_context.queue_complete_semaphores[v_context.current_frame]

	// Wait semaphore ensures that the operation cannot begin until the image is available.
	submit_info.waitSemaphoreCount = 1
	submit_info.pWaitSemaphores = &v_context.image_available_semaphores[v_context.current_frame]

	// Each semaphore waits on the corresponding pipeline stage to complete. 1:1 ratio.
	// VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT prevents subsequent colour attachment
	// writes from executing until the semaphore signals (i.e. one frame is presented at a time)
	flags: vk.PipelineStageFlags = {nil, .COLOR_ATTACHMENT_OUTPUT}
	submit_info.pWaitDstStageMask = &flags

	result := vk.QueueSubmit(
		v_context.device.graphics_queue,
		1,
		&submit_info,
		v_context.in_flight_fences[v_context.current_frame].handle,
	)
	if result != vk.Result.SUCCESS {
		log_error("vkQueueSubmit failed with result: %s", vulkan_result_string(result, true))
		return false
	}

	vulkan_command_buffer_update_submitted(command_buffer)
	// End queue submission

	// Give the image back to the swapchain.
	vulkan_swapchain_present(
		&v_context,
		&v_context.swapchain,
		v_context.device.graphics_queue,
		v_context.device.present_queue,
		&v_context.queue_complete_semaphores[v_context.current_frame],
		v_context.image_index,
	)

	return true
}

recreate_swapchain :: proc(backend: ^renderer_backend) -> bool {
	// If already being recreated, do not try again.
	if v_context.recreating_swapchain {
		log_debug("recreate_swapchain called when already recreating. Booting.")
		return false
	}

	// Detect if the window is too small to be drawn to
	if v_context.framebuffer_width == 0 || v_context.framebuffer_height == 0 {
		log_debug("recreate_swapchain called when window is < 1 in a dimension. Booting.")
		return false
	}

	// Mark as recreating if the dimensions are valid.
	v_context.recreating_swapchain = true

	// Wait for any operations to complete.
	vk.DeviceWaitIdle(v_context.device.logical_device)

	// Clear these out just in case.
	for i in 0 ..< v_context.swapchain.image_count {
		v_context.images_in_flight[i] = nil
	}

	// Requery support
	vulkan_device_query_swapchain_support(
		v_context.device.physical_device,
		v_context.surface,
		&v_context.device.swapchain_support,
	)
	vulkan_device_detect_depth_format(&v_context.device)

	vulkan_swapchain_recreate(
		&v_context,
		cached_framebuffer_width,
		cached_framebuffer_height,
		&v_context.swapchain,
	)

	// Sync the framebuffer size with the cached sizes.
	v_context.framebuffer_width = cached_framebuffer_width
	v_context.framebuffer_height = cached_framebuffer_height
	v_context.main_renderpass.w = cast(f32)v_context.framebuffer_width
	v_context.main_renderpass.h = cast(f32)v_context.framebuffer_height
	cached_framebuffer_width = 0
	cached_framebuffer_height = 0

	// Update framebuffer size generation.
	v_context.framebuffer_size_last_generation = v_context.framebuffer_size_generation

	// cleanup swapchain
	for i in 0 ..< v_context.swapchain.image_count {
		vulkan_command_buffer_free(
			&v_context,
			v_context.device.graphics_command_pool,
			&v_context.graphics_command_buffers[i],
		)
	}

	// Framebuffers.
	for i in 0 ..< v_context.swapchain.image_count {
		vulkan_framebuffer_destroy(&v_context, &v_context.swapchain.framebuffers[i])
	}

	v_context.main_renderpass.x = 0
	v_context.main_renderpass.y = 0
	v_context.main_renderpass.w = cast(f32)v_context.framebuffer_width
	v_context.main_renderpass.h = cast(f32)v_context.framebuffer_height

	regenerate_framebuffers(backend, &v_context.swapchain, &v_context.main_renderpass)

	create_command_buffers(backend)

	// Clear the recreating flag.
	v_context.recreating_swapchain = false

	return true
}

find_memory_index_proc :: proc(type_filter: u32, property_flags: vk.MemoryPropertyFlags) -> i32 {
	memory_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(v_context.device.physical_device, &memory_properties)

	for i in 0 ..< memory_properties.memoryTypeCount {
		// Check each memory type to see if its bit is set to 1
		if (type_filter & (1 << i) != 0) &&
		   (memory_properties.memoryTypes[i].propertyFlags & property_flags) == property_flags {
			return cast(i32)i
		}
	}
	log_warning("Unable to find suitable memory type!")

	return -1
}

create_command_buffers :: proc(backend: ^renderer_backend) {
	if v_context.graphics_command_buffers == nil {
		v_context.graphics_command_buffers = arr.darray_create(
			cast(u64)v_context.swapchain.image_count,
			vulkan_command_buffer,
		)
	}

	for i in 0 ..< v_context.swapchain.image_count {
		if v_context.graphics_command_buffers[i].handle != nil {
			vulkan_command_buffer_free(
				&v_context,
				v_context.device.graphics_command_pool,
				&v_context.graphics_command_buffers[i],
			)
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

regenerate_framebuffers :: proc(
	backend: ^renderer_backend,
	swapchain: ^vulkan_swapchain,
	renderpass: ^vulkan_renderpass,
) {
	for i in 0 ..< swapchain.image_count {
		// TODO: make this dynamic based on the ucrrently configured attachments
		attachment_count: u32 = 2
		attachments: [dynamic]vk.ImageView = {swapchain.views[i], swapchain.depth_attachment.view}

		vulkan_framebuffer_create(
			&v_context,
			renderpass,
			v_context.framebuffer_width,
			v_context.framebuffer_height,
			attachment_count,
			attachments,
			&v_context.swapchain.framebuffers[i],
		)
		defer arr.darray_destroy(attachments)
	}
}

create_buffers :: proc(v_context: ^vulkan_context) -> bool {
	memory_property_flags := vk.MemoryPropertyFlags{.DEVICE_LOCAL}

	vertex_buffer_size :: size_of(okmath.vertex_3d) * 1024 * 1024

	if !vulkan_buffer_create(
		v_context,
		vertex_buffer_size,
		{
			vk.BufferUsageFlag.VERTEX_BUFFER,
			vk.BufferUsageFlag.TRANSFER_DST,
			vk.BufferUsageFlag.TRANSFER_SRC,
		},
		memory_property_flags,
		true,
		&v_context.object_vertex_buffer,
	) {
		log_error("Error creating vertex buffer")
		return false
	}

	v_context.geometry_vertex_offset = 0

	index_buffer_size :: size_of(u32) * 1024 * 1024

	if !vulkan_buffer_create(
		v_context,
		index_buffer_size,
		{
			vk.BufferUsageFlag.INDEX_BUFFER,
			vk.BufferUsageFlag.TRANSFER_DST,
			vk.BufferUsageFlag.TRANSFER_SRC,
		},
		memory_property_flags,
		true,
		&v_context.object_index_buffer,
	) {
		log_error("Error creating index buffer")
		return false
	}

	v_context.geometry_index_offset = 0
	return true
}

upload_data_range :: proc(
	v_context: ^vulkan_context,
	pool: vk.CommandPool,
	fence: vk.Fence,
	queue: vk.Queue,
	buffer: ^vulkan_buffer,
	offset: u64,
	size: u64,
	data: rawptr,
) {
	// Create a host-visible staging buffer to upload to. Mark it as the source of the transfer.
	flags: vk.MemoryPropertyFlags = {
		vk.MemoryPropertyFlag.HOST_VISIBLE,
		vk.MemoryPropertyFlag.HOST_COHERENT,
	}

	staging: vulkan_buffer
	vulkan_buffer_create(v_context, size, {vk.BufferUsageFlag.TRANSFER_SRC}, flags, true, &staging)

	// Load the data into the staging buffer.
	vulkan_buffer_load_data(v_context, &staging, 0, size, {}, data)

	// Perform the copy from staging to the device local buffer.
	vulkan_buffer_copy_to(
		v_context,
		pool,
		fence,
		queue,
		staging.handle,
		0,
		buffer.handle,
		offset,
		size,
	)

	// Clean up the staging buffer
	vulkan_buffer_destroy(v_context, &staging)
}

