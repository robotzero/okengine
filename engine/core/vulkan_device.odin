package core

import vk "vendor:vulkan"

import arr "../containers"

vulkan_physical_device_requirements :: struct {
	graphics: bool,
	present: bool,
	compute: bool,
	transfer: bool,

	// darray
	device_extension_names: [dynamic]cstring,

	sampler_anisotropy: bool,
	discrete_gpu: bool,
}

vulkan_physical_device_queue_family_info :: struct {
	graphics_family_index: i32,
	present_family_index: i32,
	compute_family_index: i32,
	transfer_family_index: i32,
}

vulkan_swapchain_support_info :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	format_count: u32,
	formats: [dynamic]vk.SurfaceFormatKHR,
	present_mode_count: u32,
	present_modes: [dynamic]vk.PresentModeKHR,
}

vulkan_device :: struct {
	physical_device: vk.PhysicalDevice,
	logical_device: vk.Device,
	swapchain_support: vulkan_swapchain_support_info,
	graphics_queue_index: u32,
	present_queue_index: u32,
	transfer_queue_index: u32,

	properties: vk.PhysicalDeviceProperties,
	features: vk.PhysicalDeviceFeatures,
	memory: vk.PhysicalDeviceMemoryProperties,
}


vulkan_device_create :: proc(v_context: ^vulkan_context) -> bool {
	if select_physical_device(v_context) == false {
		return false
	}

	return true
}

vulkan_device_destroy :: proc(v_context: ^vulkan_context) {
}

vulkan_device_query_swapchain_support :: proc(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR, out_support_info: ^vulkan_swapchain_support_info) {
	// Surface capabilities
	assert(vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &out_support_info.capabilities) == vk.Result.SUCCESS)

	// Surface formats
	assert(vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &out_support_info.format_count, nil) == vk.Result.SUCCESS)

	if out_support_info.format_count != 0 {
		if out_support_info.formats == nil {
			out_support_info.formats = arr.darray_create(cast(u64)out_support_info.format_count, vk.SurfaceFormatKHR)
		}
		assert(vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &out_support_info.format_count, &out_support_info.formats[0]) == vk.Result.SUCCESS)
	}

	// Present modes
	assert(vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &out_support_info.present_mode_count, nil) == vk.Result.SUCCESS)

	if out_support_info.present_mode_count != 0 {
		if out_support_info.present_modes == nil {
			out_support_info.present_modes = arr.darray_create(cast(u64)out_support_info.present_mode_count, vk.PresentModeKHR)
		}
		assert(vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &out_support_info.present_mode_count, &out_support_info.present_modes[0]) == vk.Result.SUCCESS)
	}
}

select_physical_device :: proc(v_context: ^vulkan_context) -> bool {
	physical_device_count : u32 = 0

	assert(vk.EnumeratePhysicalDevices(v_context.instance, &physical_device_count, nil) == vk.Result.SUCCESS)

	if physical_device_count == 0 {
		log_fatal("No devices which support Vulkan were found.")
		return false
	}

	physical_devices := make([]vk.PhysicalDevice, physical_device_count)
	defer delete(physical_devices)

	assert(vk.EnumeratePhysicalDevices(v_context.instance, &physical_device_count, raw_data(physical_devices)) == vk.Result.SUCCESS)

	for dev in physical_devices {
		properties: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(dev, &properties)

		features: vk.PhysicalDeviceFeatures
		vk.GetPhysicalDeviceFeatures(dev, &features)

		memory: vk.PhysicalDeviceMemoryProperties
		vk.GetPhysicalDeviceMemoryProperties(dev, &memory)

		// @TODO: These requirements should propably be driven by engine configuration.
		requirements : vulkan_physical_device_requirements = {
			graphics = true,
			present = true,
			transfer = true,
			// @NOTE: Enable this if compute will be required.
			// compute = true,
			sampler_anisotropy = true,
			discrete_gpu = true,
			device_extension_names = arr.darray_create_default(cstring),
		}
		defer arr.darray_destroy(requirements.device_extension_names)
		arr.darray_push(&requirements.device_extension_names, vk.KHR_SWAPCHAIN_EXTENSION_NAME)

		queue_info : vulkan_physical_device_queue_family_info = {}
		result : bool = physical_device_meets_requirements(dev, v_context.surface, &properties, &features, &requirements, &queue_info, &v_context.device.swapchain_support)

		if result == true {
			log_info("Selected device: '%s'.", properties.deviceName)
			// GPU type, etc.
			switch properties.deviceType {
				case vk.PhysicalDeviceType.OTHER: log_info("GPU type is Unknown.")
				case vk.PhysicalDeviceType.INTEGRATED_GPU: log_info("GPU type is Integrated.")
				case vk.PhysicalDeviceType.DISCRETE_GPU: log_info("GPU type is Discrete.")
				case vk.PhysicalDeviceType.VIRTUAL_GPU: log_info("GPU type is Virtual.")
				case vk.PhysicalDeviceType.CPU: log_info("GPU type is CPU.")
			}
			log_info("GPU Driver version: %d.%d.%d", properties.apiVersion, properties.apiVersion, properties.apiVersion)

			for mem in memory.memoryHeaps {
				memory_size_gib : f32 = (cast(f32)mem.size) / 1024.0 / 1024.0 / 1024.0
				if vk.MemoryHeapFlag.DEVICE_LOCAL in mem.flags {
					log_info("Local GPU memory: %.2f GiB", memory_size_gib)
				} else if memory_size_gib > 0 {
					log_info("Shared system memory: %.2f GiB", memory_size_gib)
				}
			}

			v_context.device.physical_device = dev
			v_context.device.graphics_queue_index = cast(u32)queue_info.graphics_family_index
			v_context.device.present_queue_index = cast(u32)queue_info.present_family_index
			v_context.device.transfer_queue_index = cast(u32)queue_info.transfer_family_index
			// @NOTE: set compute index here if needed.

			// Keep a copy of properies, features and memory info for later use
			v_context.device.properties = properties
			v_context.device.features = features
			v_context.device.memory = memory
		}
	}

	if v_context.device.physical_device == nil {
		log_error("No physical devices were found which meet the requirements.")
		return false
	}

	log_info("Physical device selected.")

	return true
}

physical_device_meets_requirements :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
	properies: ^vk.PhysicalDeviceProperties,
	features: ^vk.PhysicalDeviceFeatures,
	requirements: ^vulkan_physical_device_requirements,
	out_queue_info: ^vulkan_physical_device_queue_family_info,
	out_swapchain_support: ^vulkan_swapchain_support_info,
) -> bool {

	defer arr.darray_destroy(out_swapchain_support.formats)
	defer arr.darray_destroy(out_swapchain_support.present_modes)
	// Evaulate device properites to determine if it meets the needs of our application.
	out_queue_info.graphics_family_index = -1
	out_queue_info.present_family_index = -1
	out_queue_info.compute_family_index = -1
	out_queue_info.transfer_family_index = -1

	// Discrete GPU?
	if requirements.discrete_gpu {
		if properies.deviceType != vk.PhysicalDeviceType.DISCRETE_GPU {
			log_info("Device is not a discrete GPU, and one is required. Skipping.")
			return false
		}
	}

	queue_family_count : u32 = 0
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)
	queue_families := make([]vk.QueueFamilyProperties, queue_family_count)
	defer delete(queue_families)

	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, raw_data(queue_families))

	// Look at each queue and see what queues it supports
	log_info("Graphics | Present | Compute | Transfer | Name")
	min_transfer_score : u8 = 255

	for queue_family, index in queue_families {
		current_transfer_score : u8 = 0

		// Graphics queue?
		if vk.QueueFlag.GRAPHICS in queue_family.queueFlags {
			out_queue_info.graphics_family_index = cast(i32)index
			current_transfer_score += current_transfer_score
		}

		// Compute queue
		if vk.QueueFlag.COMPUTE in queue_family.queueFlags {
			out_queue_info.compute_family_index = cast(i32)index
			current_transfer_score += current_transfer_score
		}

		// Transfer queue
		if vk.QueueFlag.TRANSFER in queue_family.queueFlags {
			// Take the index if it is the current lowest. This increases the
			// likehood that it is a dedicated transfer queue.
			if current_transfer_score <= min_transfer_score {
				min_transfer_score = current_transfer_score
				out_queue_info.transfer_family_index = cast(i32)index
			}
		}

		// Present queue
		supports_present : b32 = false
		assert(vk.GetPhysicalDeviceSurfaceSupportKHR(device, cast(u32)index, surface, &supports_present) == vk.Result.SUCCESS)

		if supports_present {
			out_queue_info.present_family_index = cast(i32)index
		}
	}

	{
		using out_queue_info
		using requirements
		// Print out some info about the device
		log_info("    %v |    %v |   %v |     %v | %s", graphics_family_index != -1, present_family_index != -1, compute_family_index != -1, transfer_family_index != -1, properies.deviceName)
		if
			(!graphics || (graphics && graphics_family_index != -1)) &&
			(!present || (present && present_family_index != -1)) &&
			(!compute || (compute && compute_family_index != -1)) &&
			(!transfer || (transfer && transfer_family_index != -1)) {
				log_info("Device meets queue requirements.")
				log_debug("Grahpics Family Index: %i", graphics_family_index)
				log_debug("Present Family Index: %i", present_family_index)
				log_debug("Transfer Family Index: %i", transfer_family_index)
				log_debug("Compute Family Index: %i", compute_family_index)

				// Quey swapchain support.
				vulkan_device_query_swapchain_support(device, surface, out_swapchain_support)

				if out_swapchain_support.format_count < 1 || out_swapchain_support.present_mode_count < 1 {
					if out_swapchain_support.formats != nil {
						// Not need to free, we use defer
					}
					if out_swapchain_support.present_modes != nil {
						// Not need to free, we use defer
					}
					log_info("Required swapchain support not present, skipping device.")
					return false
				}

				// Device extensions.
				if device_extension_names != nil {
					available_extension_count : u32 = 0
					available_extensions : []vk.ExtensionProperties = nil
					assert(vk.EnumerateDeviceExtensionProperties(device, nil, &available_extension_count, nil) == vk.Result.SUCCESS)

					if available_extension_count != 0 {
						available_extensions = make([]vk.ExtensionProperties, available_extension_count)
						defer delete(available_extensions)
						assert(vk.EnumerateDeviceExtensionProperties(device, nil, &available_extension_count, raw_data(available_extensions)) == vk.Result.SUCCESS)

						required_extension_count := arr.darray_length(device_extension_names)
						for extension_name in device_extension_names {
							found := false
							for available_extension in &available_extensions {
								if extension_name == cstring(&available_extension.extensionName[0]) {
									found = true
									break
								}
							}

							if !found {
								log_fatal("Required extension not found: %s, skipping device.", extension_name)
								return false
							}
						}
					}
				}

				if sampler_anisotropy && !features.samplerAnisotropy {
					log_info("Device does not support samplerAnisotropy, skipping.")
					return false
				}

				return true
			}
	}
	return false
}

