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
				log_info("Local GPU memory: %.2f GiB", memory_size_gib)
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
	// Evaulate device properites to determine if it meets the needs of our application.
	out_queue_info.graphics_family_index = -1
	out_queue_info.present_family_index = -1
	out_queue_info.compute_family_index = -1
	out_queue_info.transfer_family_index = -1

	// Discrete GPU?
	if requirements.discrete_gpu {
			
	}

	return true
}

