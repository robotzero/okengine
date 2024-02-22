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
	vk.DestroySurfaceKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroySurfaceKHR"))
	vk.DestroyInstance = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroyInstance"))
	vk.DestroyDevice = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroyDevice"))
	vk.CreateSwapchainKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateSwapchainKHR"))
	vk.GetSwapchainImagesKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetSwapchainImagesKHR"))
	vk.CreateImageView = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateImageView"))
	vk.GetPhysicalDeviceFormatProperties = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetPhysicalDeviceFormatProperties"))
	vk.CreateImage = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateImage"))
	vk.GetImageMemoryRequirements = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkGetImageMemoryRequirements"))
	vk.AllocateMemory = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkAllocateMemory"))
	vk.BindImageMemory = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkBindImageMemory"))
	vk.DestroyImageView = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroyImageView"))
	vk.DestroySwapchainKHR = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroySwapchainKHR"))
	vk.DestroyImage = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroyImage"))
	vk.FreeMemory = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkFreeMemory"))
	vk.CreateRenderPass = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateRenderPass"))
	vk.DestroyRenderPass = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroyRenderPass"))
	vk.CreateCommandPool = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateCommandPool"))
	vk.AllocateCommandBuffers = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkAllocateCommandBuffers"))
	vk.FreeCommandBuffers = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkFreeCommandBuffers"))
	vk.DestroyCommandPool = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroyCommandPool"))
	vk.CreateFramebuffer = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateFramebuffer"))
	vk.CreateSemaphore = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateSemaphore"))
	vk.CreateFence = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkCreateFence"))
	vk.DeviceWaitIdle = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDeviceWaitIdle"))
	vk.DestroySemaphore = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroySemaphore"))
	vk.DestroyFence = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroyFence"))
	vk.DestroyFramebuffer = auto_cast vk.GetInstanceProcAddr(instance, cstring("vkDestroyFramebuffer"))
}

load_proc_addresses :: proc {
	load_proc_addresses_custom,
	load_proc_adresses_instance,
}
