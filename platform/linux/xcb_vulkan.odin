package platform

import vk "vendor:vulkan"

XcbSurfaceCreateFlagsKHR :: distinct bit_set[XcbSurfaceCreateFlagKHR; vk.Flags]
XcbSurfaceCreateFlagKHR :: enum u32 {}
XcbSurfaceCreateInfoKHR :: struct {
	sType: vk.StructureType,
	pNext: rawptr,
	flags: XcbSurfaceCreateFlagsKHR,
	connection: ^Connection,
	window: Window,
}

ProcCreateXcbSurfaceKHR :: #type proc "system" (instance: vk.Instance, pCreateInfo: ^XcbSurfaceCreateInfoKHR, pAllocator: ^vk.AllocationCallbacks, pSurface: ^vk.SurfaceKHR) -> vk.Result

CreateXcbSurfaceKHR: ProcCreateXcbSurfaceKHR

load_proc_addresses_custom :: proc(set_proc_address: vk.SetProcAddressType) {
	set_proc_address(&CreateXcbSurfaceKHR, cstring("vkCreateXcbSurfaceKHR"))
}

load_proc_adresses_instance :: proc(instance: vk.Instance) {
	CreateXcbSurfaceKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateXcbSurfaceKHR"))
	vk.EnumeratePhysicalDevices = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkEnumeratePhysicalDevices"))
	vk.GetPhysicalDeviceProperties = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceProperties"))
	vk.GetPhysicalDeviceFeatures = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceFeatures"))
	vk.GetPhysicalDeviceMemoryProperties = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceMemoryProperties"))
	vk.GetPhysicalDeviceQueueFamilyProperties = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceQueueFamilyProperties"))
	vk.GetPhysicalDeviceSurfaceSupportKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceSurfaceSupportKHR"))
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceSurfaceCapabilitiesKHR"))
	vk.GetPhysicalDeviceSurfaceFormatsKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceSurfaceFormatsKHR"))
	vk.GetPhysicalDeviceSurfacePresentModesKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceSurfacePresentModesKHR"))
	vk.EnumerateDeviceExtensionProperties = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkEnumerateDeviceExtensionProperties"))
	vk.CreateDevice = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateDevice"))
	vk.GetDeviceQueue = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetDeviceQueue"))
}

load_proc_addresses :: proc {
	load_proc_addresses_custom,
	load_proc_adresses_instance,
}
