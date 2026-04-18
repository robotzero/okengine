#+feature dynamic-literals
package vulkan_renderer

import l "../../logger"
import "../../okmath"
import p "../../platform/linux"
import res "../../resources"
import rv "../../renderer"
import sys "../../systems"
import "base:runtime"
import "core:c"
import "core:mem"
import "core:strings"

import arr "../../containers"
import vk "vendor:vulkan"

// Local error enum for vulkan initialization (avoids circular import with core)
Error :: enum int {
	Okay                     = 0,
	Missing_Validation_Layer = 1,
	Create_Debugger_Fail     = 2,
}

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
		l.log_error(string(pCallbackData.pMessage))
	case vk.DebugUtilsMessageSeverityFlagEXT.WARNING:
		l.log_warning(string(pCallbackData.pMessage))
	case vk.DebugUtilsMessageSeverityFlagEXT.INFO:
		l.log_info(string(pCallbackData.pMessage))
	case vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE:
		l.log_debug(string(pCallbackData.pMessage))
	}
	return false
}

vulkan_renderer_backend_initialize :: proc(
	backend: ^rv.renderer_backend,
	application_name: string,
	framebuffer_width: u32,
	framebuffer_height: u32,
	allocator := context.allocator,
) -> bool {
	vk.load_proc_addresses_global(p.platform_initialize_vulkan())

	// Function pointers
	v_context.find_memory_index_proc = find_memory_index_proc

	// @TODO: custom allocator.
	v_context.allocator = nil

	v_context.framebuffer_width = framebuffer_width != 0 ? framebuffer_width : 800
	v_context.framebuffer_height = framebuffer_height != 0 ? framebuffer_height : 600
	cached_framebuffer_width = 0
	cached_framebuffer_height = 0

	required_extensions := arr.darray_create_default(cstring)
	arr.darray_push(&required_extensions, vk.KHR_SURFACE_EXTENSION_NAME)
	p.platform_get_required_extension_names(&required_extensions)
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
		l.log_debug("Required extensions:")
		for v, _ in required_extensions {
			l.log_debug(string(v))
		}

		// If validation should be done, get a list of the required validation layer names
		// and make sure they exist. Validation layers should only be enabled on non-release builds.
		l.log_info("Validation layers enabled. Enumerating...")

		// The list of validation layers required.
		required_validation_layer_names: [dynamic]cstring = arr.darray_create_default(cstring)
		arr.darray_push(&required_validation_layer_names, "VK_LAYER_KHRONOS_validation")
		required_validation_layer_count := u32(arr.darray_length(
			required_validation_layer_names,
		))

		// Obtain a list of available validation layers
		available_layer_count: u32 = 0
		if ok := vk.EnumerateInstanceLayerProperties(&available_layer_count, nil);
		   ok != vk.Result.SUCCESS {
			l.log_error("Failed to enumerate instance layer properties")
		}
		available_layers := arr.darray_create(u64(available_layer_count), vk.LayerProperties)
		if ok := vk.EnumerateInstanceLayerProperties(
			&available_layer_count,
			raw_data(available_layers),
		); ok != vk.Result.SUCCESS {
			l.log_error("Failed to enumerate instance layer properties")
		}

		// Verify all required layers are available
		outer: for layer_name, _ in required_validation_layer_names {
			for &layer, _ in available_layers {
				if layer_name == cstring(&layer.layerName[0]) do continue outer
			}

			l.log_fatal("Required validation layer is missing: %s", layer_name)
			return nil, 0, nil, Error.Missing_Validation_Layer
		}

		l.log_info("All required validation layers are present.")

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
			enabledExtensionCount   = u32(arr.darray_length(required_extensions)),
			ppEnabledExtensionNames = &required_extensions[0],
			enabledLayerCount       = u32(arr.darray_length(required_validation_layer_names)),
			ppEnabledLayerNames     = &required_validation_layer_names[0],
		}

	result: vk.Result = vk.CreateInstance(&create_info, v_context.allocator, &v_context.instance)
	if result != vk.Result.SUCCESS {
		l.log_error("vkCreateInstance failed with result: %u", result)
		return false
	}

	// Load instance-level proc addresses (replaces manual per-proc loading)
	vk.load_proc_addresses_instance(v_context.instance)

	when ODIN_DEBUG == true {
		create_debugger :: proc() -> Error {
			l.log_debug("Creating Vulkan debugger...")
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

			// l.log_debug("%s", msg_callback_data.pMessage)
			l.log_debug("Vulkan debugger created.")

			return Error.Okay
		}

		if err := create_debugger(); err == Error.Create_Debugger_Fail {
			return false
		}
	}

	l.log_debug("Creating Vulkan surface...")
	if p.platform_create_vulkan_surface(v_context.instance, v_context.allocator, &v_context.surface) == false {
		l.log_error("Failed to create platform surface")
		return false
	}
	l.log_debug("Vulkan surface created.")

	if vulkan_device_create(&v_context) == false {
		l.log_error("Failed to create device!")
		return false
	}

	// Swapchain
	vulkan_swapchain_create(
		&v_context,
		v_context.framebuffer_width,
		v_context.framebuffer_height,
		&v_context.swapchain,
	)

	// World renderpass: clears colour+depth, no prev pass, has next pass (UI follows).
	vulkan_renderpass_create(
		&v_context,
		&v_context.main_renderpass,
		okmath.vec4{0, 0, f32(v_context.framebuffer_width), f32(v_context.framebuffer_height)},
		okmath.vec4{0.0, 0.0, 0.2, 1.0},
		1.0,
		0,
		u8(renderpass_clear_flag.COLOUR) | u8(renderpass_clear_flag.DEPTH) | u8(renderpass_clear_flag.STENCIL),
		false,
		true,
	)

	// UI renderpass: no clear (reads from world pass output), has prev pass, no next pass.
	vulkan_renderpass_create(
		&v_context,
		&v_context.ui_renderpass,
		okmath.vec4{0, 0, f32(v_context.framebuffer_width), f32(v_context.framebuffer_height)},
		okmath.vec4{0.0, 0.0, 0.0, 0.0},
		1.0,
		0,
		u8(renderpass_clear_flag.NONE),
		true,
		false,
	)

	// Create framebuffers for both world (color+depth) and UI (color only) passes.
	regenerate_framebuffers()

	// Create command buffers.
	create_command_buffers(backend)

	// Create sync objects.
	v_context.image_available_semaphores = arr.darray_create(
		u64(v_context.swapchain.max_frames_in_flight),
		vk.Semaphore,
	)
	v_context.queue_complete_semaphores = arr.darray_create(
		u64(v_context.swapchain.max_frames_in_flight),
		vk.Semaphore,
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

		// Create fence in signaled state so the first frame doesn't wait forever.
		fence_create_info := vk.FenceCreateInfo {
			sType = .FENCE_CREATE_INFO,
			flags = {.SIGNALED},
		}
		assert(
			vk.CreateFence(
				v_context.device.logical_device,
				&fence_create_info,
				v_context.allocator,
				&v_context.in_flight_fences[i],
			) == vk.Result.SUCCESS,
		)
	}

	// images_in_flight tracks per-image fence handles (0 = not in use).
	v_context.images_in_flight = make([]vk.Fence, v_context.swapchain.image_count)

	// Create built-in shaders
	if !vulkan_material_shader_create(&v_context, &v_context.material_shader) {
		l.log_error("Error loading built-in basic_lighting shader")
		return false
	}

	if !vulkan_ui_shader_create(&v_context, &v_context.ui_shader) {
		l.log_error("Error loading built-in UI shader")
		return false
	}

	create_buffers(&v_context)

	// Invalidate all geometries in the array.
	for i in 0 ..< VULKAN_MAX_GEOMETRY_COUNT {
		v_context.geometries[i].id = INVALID_ID
		v_context.geometries[i].generation = INVALID_ID
	}

	l.log_info("Vulkan renderer initialized successfully.")

	return true
}

vulkan_renderer_backend_shutdown :: proc(backend: ^rv.renderer_backend) {
	vk.DeviceWaitIdle(v_context.device.logical_device)
	// Destroy is the opposite order of creation.
	vulkan_buffer_destroy(&v_context, &v_context.object_vertex_buffer)
	vulkan_buffer_destroy(&v_context, &v_context.object_index_buffer)
	vulkan_ui_shader_destroy(&v_context, &v_context.ui_shader)
	vulkan_material_shader_destroy(&v_context, &v_context.material_shader)

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
		if v_context.in_flight_fences[i] != 0 {
			vk.DestroyFence(
				v_context.device.logical_device,
				v_context.in_flight_fences[i],
				v_context.allocator,
			)
			v_context.in_flight_fences[i] = 0
		}
	}
	arr.darray_destroy(v_context.image_available_semaphores)
	v_context.image_available_semaphores = nil

	arr.darray_destroy(v_context.queue_complete_semaphores)
	v_context.queue_complete_semaphores = nil

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

	// Destroy world framebuffers (color+depth).
	for fb in v_context.world_framebuffers {
		if fb != 0 {
			vk.DestroyFramebuffer(v_context.device.logical_device, fb, v_context.allocator)
		}
	}
	delete(v_context.world_framebuffers)
	v_context.world_framebuffers = nil

	// Destroy UI framebuffers (color only).
	for fb in v_context.swapchain.framebuffers {
		if fb != 0 {
			vk.DestroyFramebuffer(v_context.device.logical_device, fb, v_context.allocator)
		}
	}
	delete(v_context.swapchain.framebuffers)
	v_context.swapchain.framebuffers = nil

	delete(v_context.images_in_flight)
	v_context.images_in_flight = nil

	delete(v_context.swapchain.images)
	delete(v_context.swapchain.views)

	// Renderpasses
	vulkan_renderpass_destroy(&v_context, &v_context.ui_renderpass)
	vulkan_renderpass_destroy(&v_context, &v_context.main_renderpass)

	// Swapchain
	vulkan_swapchain_destroy(&v_context, &v_context.swapchain)

	l.log_debug("Destroying Vulkan device...")
	vulkan_device_destroy(&v_context)

	l.log_debug("Destroying Vulkan surface...")
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
				l.log_debug("Destroying Vulkan debugger...")
			}
		}
	}

	if v_context.instance != nil {
		l.log_debug("Destroying Vulkan instance...")
		vk.DestroyInstance(v_context.instance, v_context.allocator)
	}
}

vulkan_renderer_backend_on_resized :: proc(
	backend: ^rv.renderer_backend,
	width: u16,
	height: u16,
) {
	// Update the "framebuffer size generation", a counter which indicates when the
	// framebuffer size has been updated.
	cached_framebuffer_width = u32(width)
	cached_framebuffer_height = u32(height)
	v_context.framebuffer_size_generation = v_context.framebuffer_size_generation + 1

	l.log_info(
		"Vulkan renderer backend->resized: w/g/gen: %i/%i/%v",
		width,
		height,
		v_context.framebuffer_size_generation,
	)
}

vulkan_renderer_backend_begin_frame :: proc(
	backend: ^rv.renderer_backend,
	delta_time: f32,
) -> bool {
	v_context.frame_delta_time = delta_time
	device: ^vulkan_device = &v_context.device

	// Check if recreating swap chain and boot out.
	if v_context.recreating_swapchain {
		result := vk.DeviceWaitIdle(device.logical_device)

		if !vulkan_result_is_success(result) {
			l.log_error(
				"vulkan renderer backend begin frame vkDeviceWaitIdle (1), failed: '%s'",
				vulkan_result_string(result, true),
			)
			return false
		}

		l.log_info("Recreating swapchain, booting")
		return false
	}

	// Check if the framebuffer has been resized. If so, a new swapchain must be created.
	if v_context.framebuffer_size_generation != v_context.framebuffer_size_last_generation {
		result := vk.DeviceWaitIdle(device.logical_device)

		if !vulkan_result_is_success(result) {
			l.log_error(
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

		l.log_info("Resized, booting")
		return false
	}

	// Wait for the execution of the current frame to complete.
	result := vk.WaitForFences(
		device.logical_device,
		1,
		&v_context.in_flight_fences[v_context.current_frame],
		true,
		max(u64),
	)
	if result != vk.Result.SUCCESS {
		l.log_warning("In-flight fence wait failure!")
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
	viewport := vk.Viewport {
		x        = 0.0,
		y        = f32(v_context.framebuffer_height),
		width    = f32(v_context.framebuffer_width),
		height   = -f32(v_context.framebuffer_height),
		minDepth = 0.0,
		maxDepth = 1.0,
	}

	// Scissor
	scissor := vk.Rect2D {
		offset = {x = 0, y = 0},
		extent = {width = v_context.framebuffer_width, height = v_context.framebuffer_height},
	}

	vk.CmdSetViewport(command_buffer.handle, 0, 1, &viewport)
	vk.CmdSetScissor(command_buffer.handle, 0, 1, &scissor)

	v_context.main_renderpass.render_area.z = f32(v_context.framebuffer_width)
	v_context.main_renderpass.render_area.w = f32(v_context.framebuffer_height)
	v_context.ui_renderpass.render_area.z = f32(v_context.framebuffer_width)
	v_context.ui_renderpass.render_area.w = f32(v_context.framebuffer_height)

	return true
}

vulkan_renderer_backend_end_frame :: proc(backend: ^rv.renderer_backend, delta_time: f32) -> bool {
	command_buffer: ^vulkan_command_buffer = &v_context.graphics_command_buffers[v_context.image_index]

	vulkan_command_buffer_end(command_buffer)

	// Make sure the previous frame is not using this image (i.e. its fence is being waited on).
	if v_context.images_in_flight[v_context.image_index] != 0 {
		vk.WaitForFences(
			v_context.device.logical_device,
			1,
			&v_context.images_in_flight[v_context.image_index],
			true,
			c.UINT64_MAX,
		)
	}

	// Mark the image fence as in-use by this frame.
	v_context.images_in_flight[v_context.image_index] =
		v_context.in_flight_fences[v_context.current_frame]

	// Reset the fence for use on the next frame.
	vk.ResetFences(v_context.device.logical_device, 1, &v_context.in_flight_fences[v_context.current_frame])

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
		v_context.in_flight_fences[v_context.current_frame],
	)
	if result != vk.Result.SUCCESS {
		l.log_error("vkQueueSubmit failed with result: %s", vulkan_result_string(result, true))
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

recreate_swapchain :: proc(backend: ^rv.renderer_backend) -> bool {
	// If already being recreated, do not try again.
	if v_context.recreating_swapchain {
		l.log_debug("recreate_swapchain called when already recreating. Booting.")
		return false
	}

	// Detect if the window is too small to be drawn to
	if v_context.framebuffer_width == 0 || v_context.framebuffer_height == 0 {
		l.log_debug("recreate_swapchain called when window is < 1 in a dimension. Booting.")
		return false
	}

	// Mark as recreating if the dimensions are valid.
	v_context.recreating_swapchain = true

	// Wait for any operations to complete.
	vk.DeviceWaitIdle(v_context.device.logical_device)

	// Clear these out just in case.
	for i in 0 ..< v_context.swapchain.image_count {
		v_context.images_in_flight[i] = 0
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
	v_context.main_renderpass.render_area.z = f32(v_context.framebuffer_width)
	v_context.main_renderpass.render_area.w = f32(v_context.framebuffer_height)
	v_context.ui_renderpass.render_area.z = f32(v_context.framebuffer_width)
	v_context.ui_renderpass.render_area.w = f32(v_context.framebuffer_height)
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

	// Destroy world framebuffers.
	for fb in v_context.world_framebuffers {
		if fb != 0 {
			vk.DestroyFramebuffer(v_context.device.logical_device, fb, v_context.allocator)
		}
	}
	delete(v_context.world_framebuffers)
	v_context.world_framebuffers = nil

	// Destroy UI framebuffers.
	for fb in v_context.swapchain.framebuffers {
		if fb != 0 {
			vk.DestroyFramebuffer(v_context.device.logical_device, fb, v_context.allocator)
		}
	}
	delete(v_context.swapchain.framebuffers)
	v_context.swapchain.framebuffers = nil

	v_context.main_renderpass.render_area.x = 0
	v_context.main_renderpass.render_area.y = 0
	v_context.main_renderpass.render_area.z = f32(v_context.framebuffer_width)
	v_context.main_renderpass.render_area.w = f32(v_context.framebuffer_height)
	v_context.ui_renderpass.render_area.x = 0
	v_context.ui_renderpass.render_area.y = 0
	v_context.ui_renderpass.render_area.z = f32(v_context.framebuffer_width)
	v_context.ui_renderpass.render_area.w = f32(v_context.framebuffer_height)

	regenerate_framebuffers()

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
			return i32(i)
		}
	}
	l.log_warning("Unable to find suitable memory type!")

	return -1
}

create_command_buffers :: proc(backend: ^rv.renderer_backend) {
	if v_context.graphics_command_buffers == nil {
		v_context.graphics_command_buffers = arr.darray_create(
			u64(v_context.swapchain.image_count),
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

	l.log_debug("Vulkan command buffers created.")
}

regenerate_framebuffers :: proc() {
	count := v_context.swapchain.image_count

	// Allocate slices if not already done.
	if v_context.world_framebuffers == nil {
		v_context.world_framebuffers = make([]vk.Framebuffer, count)
	}
	if v_context.swapchain.framebuffers == nil {
		v_context.swapchain.framebuffers = make([]vk.Framebuffer, count)
	}

	for i in 0 ..< count {
		// World framebuffer: color + depth attachments.
		world_attachments: [2]vk.ImageView = {
			v_context.swapchain.views[i],
			v_context.swapchain.depth_attachment.view,
		}
		world_fb_info := vk.FramebufferCreateInfo {
			sType           = .FRAMEBUFFER_CREATE_INFO,
			renderPass      = v_context.main_renderpass.handle,
			attachmentCount = 2,
			pAttachments    = &world_attachments[0],
			width           = v_context.framebuffer_width,
			height          = v_context.framebuffer_height,
			layers          = 1,
		}
		assert(
			vk.CreateFramebuffer(
				v_context.device.logical_device,
				&world_fb_info,
				v_context.allocator,
				&v_context.world_framebuffers[i],
			) == vk.Result.SUCCESS,
		)

		// UI framebuffer: color only (no depth).
		ui_fb_info := vk.FramebufferCreateInfo {
			sType           = .FRAMEBUFFER_CREATE_INFO,
			renderPass      = v_context.ui_renderpass.handle,
			attachmentCount = 1,
			pAttachments    = &v_context.swapchain.views[i],
			width           = v_context.framebuffer_width,
			height          = v_context.framebuffer_height,
			layers          = 1,
		}
		assert(
			vk.CreateFramebuffer(
				v_context.device.logical_device,
				&ui_fb_info,
				v_context.allocator,
				&v_context.swapchain.framebuffers[i],
			) == vk.Result.SUCCESS,
		)
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
		l.log_error("Error creating vertex buffer")
		return false
	}

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
		l.log_error("Error creating index buffer")
		return false
	}

	return true
}

// Allocates space in the buffer via the freelist, uploads data via a staging buffer,
// and writes the allocated offset into out_offset. Returns false on failure.
upload_data_range :: proc(
	v_context: ^vulkan_context,
	pool: vk.CommandPool,
	fence: vk.Fence,
	queue: vk.Queue,
	buffer: ^vulkan_buffer,
	out_offset: ^u64,
	size: u64,
	data: rawptr,
) -> bool {
	if !vulkan_buffer_allocate(buffer, size, out_offset) {
		l.log_error("upload_data_range failed to allocate from the given buffer!")
		return false
	}

	// Create a host-visible staging buffer to upload to.
	flags: vk.MemoryPropertyFlags = {
		vk.MemoryPropertyFlag.HOST_VISIBLE,
		vk.MemoryPropertyFlag.HOST_COHERENT,
	}

	staging: vulkan_buffer
	vulkan_buffer_create(
		v_context,
		vk.DeviceSize(size),
		{vk.BufferUsageFlag.TRANSFER_SRC},
		flags,
		true,
		&staging,
	)

	vulkan_buffer_load_data(v_context, &staging, 0, size, {}, data)

	vulkan_buffer_copy_to(
		v_context,
		pool,
		fence,
		queue,
		staging.handle,
		0,
		buffer.handle,
		out_offset^,
		size,
	)

	vulkan_buffer_destroy(v_context, &staging)
	return true
}

vulkan_renderer_update_global_world_state :: proc(
	projection: okmath.mat4,
	view: okmath.mat4,
	view_position: okmath.vec3,
	ambient_colour: okmath.vec4,
	mode: i32,
) {
	vulkan_material_shader_use(&v_context, &v_context.material_shader)

	v_context.material_shader.global_ubo.projection = projection
	v_context.material_shader.global_ubo.view = view

	vulkan_material_shader_update_global_state(
		&v_context,
		&v_context.material_shader,
		v_context.frame_delta_time,
	)
}

vulkan_renderer_update_global_ui_state :: proc(
	projection: okmath.mat4,
	view: okmath.mat4,
	mode: i32,
) {
	vulkan_ui_shader_use(&v_context, &v_context.ui_shader)

	v_context.ui_shader.global_ubo.projection = projection
	v_context.ui_shader.global_ubo.view = view

	vulkan_ui_shader_update_global_state(
		&v_context,
		&v_context.ui_shader,
		v_context.frame_delta_time,
	)
}

vulkan_renderer_begin_renderpass :: proc(backend: ^rv.renderer_backend, renderpass_id: u8) -> bool {
	command_buffer := &v_context.graphics_command_buffers[v_context.image_index]

	switch rv.builtin_renderpass(renderpass_id) {
	case .WORLD:
		vulkan_renderpass_begin(
			command_buffer,
			&v_context.main_renderpass,
			v_context.world_framebuffers[v_context.image_index],
		)
	case .UI:
		vulkan_renderpass_begin(
			command_buffer,
			&v_context.ui_renderpass,
			v_context.swapchain.framebuffers[v_context.image_index],
		)
		// UI uses a non-flipped viewport to match the orthographic projection (y-down, origin top-left).
		ui_viewport := vk.Viewport {
			x        = 0.0,
			y        = 0.0,
			width    = f32(v_context.framebuffer_width),
			height   = f32(v_context.framebuffer_height),
			minDepth = 0.0,
			maxDepth = 1.0,
		}
		vk.CmdSetViewport(command_buffer.handle, 0, 1, &ui_viewport)
	case:
		l.log_error("vulkan_renderer_begin_renderpass: unknown renderpass id %v", renderpass_id)
		return false
	}

	return true
}

vulkan_renderer_end_renderpass :: proc(backend: ^rv.renderer_backend, renderpass_id: u8) -> bool {
	command_buffer := &v_context.graphics_command_buffers[v_context.image_index]

	switch rv.builtin_renderpass(renderpass_id) {
	case .WORLD:
		vulkan_renderpass_end(command_buffer, &v_context.main_renderpass)
	case .UI:
		vulkan_renderpass_end(command_buffer, &v_context.ui_renderpass)
	case:
		l.log_error("vulkan_renderer_end_renderpass: unknown renderpass id %v", renderpass_id)
		return false
	}

	return true
}

free_data_range :: proc(buffer: ^vulkan_buffer, offset: u64, size: u64) {
	if buffer != nil {
		vulkan_buffer_free(buffer, size, offset)
	}
}

vulkan_renderer_create_geometry :: proc(
	geom: ^res.geometry,
	vertex_count: u32,
	vertex_size: u32,
	vertices: rawptr,
	index_count: u32,
	index_size: u32,
	indices: rawptr,
) -> bool {
	if vertex_count == 0 || vertex_size == 0 || vertices == nil {
		l.log_error(
			"vulkan_renderer_create_geometry requires vertex data, and none was supplied.",
		)
		return false
	}

	// Check if this is a re-upload. If it is, need to free old data afterward.
	is_reupload := geom.internal_id != INVALID_ID
	old_range: vulkan_geometry_data

	internal_data: ^vulkan_geometry_data = nil
	if is_reupload {
		internal_data = &v_context.geometries[geom.internal_id]
		old_range = internal_data^
	} else {
		for i in 0 ..< u32(VULKAN_MAX_GEOMETRY_COUNT) {
			if v_context.geometries[i].id == INVALID_ID {
				geom.internal_id = i
				v_context.geometries[i].id = i
				internal_data = &v_context.geometries[i]
				break
			}
		}
	}

	if internal_data == nil {
		l.log_fatal(
			"vulkan_renderer_create_geometry failed to find a free index. Adjust config to allow for more.",
		)
		return false
	}

	pool := v_context.device.graphics_command_pool
	queue := v_context.device.graphics_queue

	// Vertex data.
	internal_data.vertex_count = vertex_count
	internal_data.vertex_element_size = u64(vertex_size) * u64(vertex_count)
	if !upload_data_range(
		&v_context,
		pool,
		0,
		queue,
		&v_context.object_vertex_buffer,
		&internal_data.vertex_buffer_offset,
		internal_data.vertex_element_size,
		vertices,
	) {
		l.log_error("vulkan_renderer_create_geometry failed to upload to the vertex buffer!")
		return false
	}

	// Index data, if applicable.
	if index_count > 0 && index_size > 0 && indices != nil {
		internal_data.index_count = index_count
		internal_data.index_element_size = u64(index_size) * u64(index_count)
		if !upload_data_range(
			&v_context,
			pool,
			0,
			queue,
			&v_context.object_index_buffer,
			&internal_data.index_buffer_offset,
			internal_data.index_element_size,
			indices,
		) {
			l.log_error("vulkan_renderer_create_geometry failed to upload to the index buffer!")
			return false
		}
	}

	if internal_data.generation == INVALID_ID {
		internal_data.generation = 0
	} else {
		internal_data.generation += 1
	}

	if is_reupload {
		// Free vertex data.
		free_data_range(&v_context.object_vertex_buffer, old_range.vertex_buffer_offset, old_range.vertex_element_size)
		// Free index data, if applicable.
		if old_range.index_element_size > 0 {
			free_data_range(
				&v_context.object_index_buffer,
				old_range.index_buffer_offset,
				old_range.index_element_size,
			)
		}
	}

	return true
}

vulkan_renderer_destroy_geometry :: proc(geom: ^res.geometry) {
	if geom != nil && geom.internal_id != INVALID_ID {
		vk.DeviceWaitIdle(v_context.device.logical_device)
		internal_data := &v_context.geometries[geom.internal_id]

		// Free vertex data.
		free_data_range(
			&v_context.object_vertex_buffer,
			internal_data.vertex_buffer_offset,
			internal_data.vertex_element_size,
		)

		// Free index data, if applicable.
		if internal_data.index_element_size > 0 {
			free_data_range(
				&v_context.object_index_buffer,
				internal_data.index_buffer_offset,
				internal_data.index_element_size,
			)
		}

		// Clean up data.
		internal_data^ = {}
		internal_data.id = INVALID_ID
		internal_data.generation = INVALID_ID
	}
}

vulkan_renderer_draw_geometry :: proc(data: geometry_render_data) {
	// Ignore non-uploaded geometries.
	if data.geometry != nil && data.geometry.internal_id == INVALID_ID {
		return
	}

	buffer_data := &v_context.geometries[data.geometry.internal_id]
	command_buffer := &v_context.graphics_command_buffers[v_context.image_index]

	// Bind vertex buffer at offset.
	offsets: [1]vk.DeviceSize = {vk.DeviceSize(buffer_data.vertex_buffer_offset)}
	vk.CmdBindVertexBuffers(
		command_buffer.handle,
		0,
		1,
		&v_context.object_vertex_buffer.handle,
		&offsets[0],
	)

	// Draw indexed or non-indexed.
	if buffer_data.index_count > 0 {
		// Bind index buffer at offset.
		vk.CmdBindIndexBuffer(
			command_buffer.handle,
			v_context.object_index_buffer.handle,
			vk.DeviceSize(buffer_data.index_buffer_offset),
			vk.IndexType.UINT32,
		)
		// Issue the draw.
		vk.CmdDrawIndexed(command_buffer.handle, buffer_data.index_count, 1, 0, 0, 0)
	} else {
		vk.CmdDraw(command_buffer.handle, buffer_data.vertex_count, 1, 0, 0)
	}
}

vulkan_renderer_create_texture :: proc(pixels: []u8, texture: ^res.texture) {
	// Internal data creation.
	// TODO: Use an allocator for this.
	texture_alloc := runtime.default_context().allocator
	data := new(vulkan_texture_data, texture_alloc)
	texture.internal_data = data
	temp_size := u32(texture.width) * u32(texture.height) * u32(texture.channel_count)
	image_size: vk.DeviceSize = vk.DeviceSize(u64(temp_size))

	// NOTE: Assumes 8 bits per channel.
	image_format := vk.Format.R8G8B8A8_UNORM

	// Create a staging buffer and load data into it.
	usage := vk.BufferUsageFlags{.TRANSFER_SRC}
	memory_prop_flags := vk.MemoryPropertyFlags{.HOST_VISIBLE, .HOST_COHERENT}
	staging: vulkan_buffer
	vulkan_buffer_create(&v_context, image_size, usage, memory_prop_flags, true, &staging)
	l.log_debug(
		"CreateTexture: size=%u w=%d h=%d channels=%d staging=%p",
		u64(image_size),
		texture.width,
		texture.height,
		texture.channel_count,
		staging.handle,
	)
	l.log_debug("CreateTexture: pixel_len=%d", len(pixels))

	vulkan_buffer_load_data(&v_context, &staging, 0, u64(image_size), {}, raw_data(pixels))

	// NOTE: Lots of assumptions here, different texture types will require different options here.
	vulkan_image_create(
		&v_context,
		vk.ImageType.D2,
		u32(texture.width),
		u32(texture.height),
		image_format,
		vk.ImageTiling.OPTIMAL,
		{
			vk.ImageUsageFlag.TRANSFER_SRC,
			vk.ImageUsageFlag.TRANSFER_DST,
			vk.ImageUsageFlag.SAMPLED,
			vk.ImageUsageFlag.COLOR_ATTACHMENT,
		},
		{vk.MemoryPropertyFlag.DEVICE_LOCAL},
		true,
		{.COLOR},
		&data.image,
	)
	l.log_debug("CreateTexture: image=%p view=%p", data.image.handle, data.image.view)

	temp_buffer: vulkan_command_buffer
	pool := v_context.device.graphics_command_pool
	queue := v_context.device.graphics_queue
	vulkan_command_buffer_allocate_and_begin_single_use(&v_context, pool, &temp_buffer)

	// Transition the layout from whatever it is currently to optimal for receiving data.
	vulkan_image_transition_layout(
		&v_context,
		&temp_buffer,
		&data.image,
		image_format,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
	)

	// Copy the data from the buffer.
	vulkan_image_copy_from_buffer(&v_context, &data.image, staging.handle, &temp_buffer)

	// Transition from optimal for data receipt to shader-read-only optimal layout.
	vulkan_image_transition_layout(
		&v_context,
		&temp_buffer,
		&data.image,
		image_format,
		.TRANSFER_DST_OPTIMAL,
		.SHADER_READ_ONLY_OPTIMAL,
	)

	vulkan_command_buffer_end_single_use(&v_context, pool, &temp_buffer, queue)

	vulkan_buffer_destroy(&v_context, &staging)
	// Create a sampler for the texture.
	sampler_info := vk.SamplerCreateInfo {
		sType = .SAMPLER_CREATE_INFO,
	}
	// TODO: These filters should be configurable.
	sampler_info.magFilter = vk.Filter.LINEAR
	sampler_info.minFilter = vk.Filter.LINEAR
	sampler_info.addressModeU = vk.SamplerAddressMode.REPEAT
	sampler_info.addressModeV = vk.SamplerAddressMode.REPEAT
	sampler_info.addressModeW = vk.SamplerAddressMode.REPEAT
	sampler_info.anisotropyEnable = true
	sampler_info.maxAnisotropy = 16.0
	sampler_info.borderColor = vk.BorderColor.INT_OPAQUE_BLACK
	sampler_info.unnormalizedCoordinates = false
	sampler_info.compareEnable = false
	sampler_info.compareOp = vk.CompareOp.ALWAYS
	sampler_info.mipmapMode = vk.SamplerMipmapMode.LINEAR
	sampler_info.mipLodBias = 0.0
	sampler_info.minLod = 0.0
	sampler_info.maxLod = 0.0

	result := vk.CreateSampler(
		v_context.device.logical_device,
		&sampler_info,
		v_context.allocator,
		&data.sampler,
	)
	if !vulkan_result_is_success(result) {
		l.log_error("Error creating texture sampler: %s", vulkan_result_string(result, true))
		return
	}

	texture.generation += 1

}

vulkan_renderer_destroy_texture :: proc(texture: ^res.texture) {
	vk.DeviceWaitIdle(v_context.device.logical_device)
	data := cast(^vulkan_texture_data)texture.internal_data
	if data == nil {
		return
	}

	vulkan_image_destroy(&v_context, &data.image)
	data.image = {}
	vk.DestroySampler(v_context.device.logical_device, data.sampler, v_context.allocator)
	data.sampler = 0

	texture_alloc := runtime.default_context().allocator
	free(data, texture_alloc)
	// Clear the full texture struct, not just pointer-sized bytes.
	texture^ = {}
}

// ── Generic shader backend procs ──────────────────────────────────────────────

vulkan_renderer_shader_create :: proc(
	s: ^res.shader,
	renderpass_id: u8,
	stage_count: u8,
	stage_filenames: []string,
	stages: []res.shader_stage,
) -> bool {
	switch rv.builtin_renderpass(renderpass_id) {
	case .WORLD:
		s.internal_data = &v_context.material_shader
	case .UI:
		s.internal_data = &v_context.ui_shader
	}
	return true
}

vulkan_renderer_shader_destroy :: proc(s: ^res.shader) {
	s.internal_data = nil
}

vulkan_renderer_shader_initialize :: proc(s: ^res.shader) -> bool {
	return true
}

vulkan_renderer_shader_use :: proc(s: ^res.shader) -> bool {
	if s.internal_data == nil {
		return false
	}
	// Determine which hardcoded shader this is by internal_data pointer.
	if s.internal_data == &v_context.material_shader {
		vulkan_material_shader_use(&v_context, &v_context.material_shader)
	} else if s.internal_data == &v_context.ui_shader {
		vulkan_ui_shader_use(&v_context, &v_context.ui_shader)
	}
	return true
}

vulkan_renderer_shader_bind_globals :: proc(s: ^res.shader) -> bool {
	return true
}

vulkan_renderer_shader_bind_instance :: proc(s: ^res.shader, instance_id: u32) -> bool {
	s.bound_instance_id = instance_id
	return true
}

vulkan_renderer_shader_apply_globals :: proc(s: ^res.shader) -> bool {
	if s.internal_data == nil {
		return false
	}
	if s.internal_data == &v_context.material_shader {
		vulkan_material_shader_update_global_state(
			&v_context,
			&v_context.material_shader,
			v_context.frame_delta_time,
		)
	} else if s.internal_data == &v_context.ui_shader {
		vulkan_ui_shader_update_global_state(
			&v_context,
			&v_context.ui_shader,
			v_context.frame_delta_time,
		)
	}
	return true
}

vulkan_renderer_shader_apply_instance :: proc(s: ^res.shader) -> bool {
	if s.internal_data == nil {
		return false
	}
	// Build a proxy material from the staged instance uniforms and flush to GPU.
	// Use INVALID_ID as generation to force descriptor re-upload every frame
	// (we don't track real material generations through the generic shader path yet).
	if s.internal_data == &v_context.material_shader {
		ms := &v_context.material_shader
		proxy: res.material
		proxy.internal_id = s.bound_instance_id
		proxy.diffuse_colour = ms.staged.diffuse_colour
		proxy.diffuse_map.texture = ms.staged.diffuse_map
		proxy.generation = INVALID_ID
		vulkan_material_shader_apply_material(&v_context, ms, &proxy)
	} else if s.internal_data == &v_context.ui_shader {
		us := &v_context.ui_shader
		proxy: res.material
		proxy.internal_id = s.bound_instance_id
		proxy.diffuse_colour = us.staged.diffuse_colour
		proxy.diffuse_map.texture = us.staged.diffuse_map
		proxy.generation = INVALID_ID
		vulkan_ui_shader_apply_material(&v_context, us, &proxy)
	}
	return true
}

vulkan_renderer_shader_acquire_instance_resources :: proc(
	s: ^res.shader,
	out_instance_id: ^u32,
) -> bool {
	if s.internal_data == nil {
		return false
	}
	// Create a temporary material proxy to use the acquire_resources procs.
	proxy: res.material
	proxy.internal_id = INVALID_ID
	if s.internal_data == &v_context.material_shader {
		if !vulkan_material_shader_acquire_resources(&v_context, &v_context.material_shader, &proxy) {
			return false
		}
	} else if s.internal_data == &v_context.ui_shader {
		if !vulkan_ui_shader_acquire_resources(&v_context, &v_context.ui_shader, &proxy) {
			return false
		}
	}
	out_instance_id^ = proxy.internal_id
	return true
}

vulkan_renderer_shader_release_instance_resources :: proc(
	s: ^res.shader,
	instance_id: u32,
) -> bool {
	if s.internal_data == nil {
		return false
	}
	proxy: res.material
	proxy.internal_id = instance_id
	if s.internal_data == &v_context.material_shader {
		vulkan_material_shader_release_resources(&v_context, &v_context.material_shader, &proxy)
	} else if s.internal_data == &v_context.ui_shader {
		vulkan_ui_shader_release_resources(&v_context, &v_context.ui_shader, &proxy)
	}
	return true
}

vulkan_renderer_set_uniform :: proc(
	s: ^res.shader,
	uniform: ^res.shader_uniform,
	value: rawptr,
) -> bool {
	if s.internal_data == nil || uniform == nil {
		return false
	}
	// Route uniform sets to the appropriate hardcoded shader structs.
	// Material shader uniform indices (from Shader.Builtin.Material.shadercfg):
	//   global:   0=projection, 1=view, 2=ambient_colour
	//   instance: 3=diffuse_colour, 4=diffuse_texture
	//   local:    5=model
	if s.internal_data == &v_context.material_shader {
		ms := &v_context.material_shader
		switch uniform.scope {
		case .GLOBAL:
			if uniform.index == 0 {
				ms.global_ubo.projection = (^okmath.mat4)(value)^
			} else if uniform.index == 1 {
				ms.global_ubo.view = (^okmath.mat4)(value)^
			} else if uniform.index == 2 {
				ms.global_ubo.ambient_colour = (^okmath.vec4)(value)^
			}
		case .INSTANCE:
			if uniform.index == 3 {
				ms.staged.diffuse_colour = (^okmath.vec4)(value)^
			} else if uniform.index == 4 {
				ms.staged.diffuse_map = (^^res.texture)(value)^
			}
		case .LOCAL:
			// model matrix push constant — push immediately
			if uniform.index == 5 {
				image_index := int(v_context.image_index)
				command_buffer := v_context.graphics_command_buffers[image_index].handle
				model := (^okmath.mat4)(value)^
				vk.CmdPushConstants(
					command_buffer,
					ms.pipeline.pipeline_layout,
					{.VERTEX},
					0,
					size_of(okmath.mat4),
					&model,
				)
			}
		}
	} else if s.internal_data == &v_context.ui_shader {
		// UI shader uniform indices (from Shader.Builtin.UI.shadercfg):
		//   global:   0=projection, 1=view
		//   instance: 2=diffuse_colour, 3=diffuse_texture
		//   local:    4=model
		us := &v_context.ui_shader
		switch uniform.scope {
		case .GLOBAL:
			if uniform.index == 0 {
				us.global_ubo.projection = (^okmath.mat4)(value)^
			} else if uniform.index == 1 {
				us.global_ubo.view = (^okmath.mat4)(value)^
			}
		case .INSTANCE:
			if uniform.index == 2 {
				us.staged.diffuse_colour = (^okmath.vec4)(value)^
			} else if uniform.index == 3 {
				us.staged.diffuse_map = (^^res.texture)(value)^
			}
		case .LOCAL:
			if uniform.index == 4 {
				image_index := int(v_context.image_index)
				command_buffer := v_context.graphics_command_buffers[image_index].handle
				model := (^okmath.mat4)(value)^
				vk.CmdPushConstants(
					command_buffer,
					us.pipeline.pipeline_layout,
					{.VERTEX},
					0,
					size_of(okmath.mat4),
					&model,
				)
			}
		}
	}
	return true
}

