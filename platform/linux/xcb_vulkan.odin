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
}

load_proc_addresses :: proc {
	load_proc_addresses_custom,
	load_proc_adresses_instance,
}
