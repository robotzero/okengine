package platform

// Vulkan XCB surface support is now provided by the vendor:vulkan package.
// See vk.XcbSurfaceCreateInfoKHR, vk.CreateXcbSurfaceKHR.
//
// Proc loading is handled by:
//   vk.load_proc_addresses_global    — pre-instance procs
//   vk.load_proc_addresses_instance  — instance-level procs (+ XCB surface)
//   vk.load_proc_addresses_device    — device-level procs
