package core

import "core:mem"
import vk "vendor:vulkan"

vulkan_buffer_create :: proc(
	v_context: ^vulkan_context,
	size: u64,
	usage: vk.BufferUsageFlags, // or vk.BufferUsageFlags depending on your bindings
	memory_property_flags: vk.MemoryPropertyFlags,
	bind_on_create: b8,
	out_buffer: ^vulkan_buffer,
) -> b8 {
	kzero_memory(out_buffer, size_of(vulkan_buffer))

	out_buffer.total_size = size
	out_buffer.usage = usage
	out_buffer.memory_property_flags = memory_property_flags

	buffer_info := vk.BufferCreateInfo {
		sType       = .BUFFER_CREATE_INFO,
		size        = vk.DeviceSize(size),
		usage       = usage,
		sharingMode = .EXCLUSIVE,
	}

	// Replace VK_CHECK with your helper if you have one.
	res := vk.CreateBuffer(
		v_context.device.logical_device,
		&buffer_info,
		v_context.allocator,
		&out_buffer.handle,
	)
	if res != vk.Result.SUCCESS {
		return false
	}

	// Memory requirements
	requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(
		v_context.device.logical_device,
		out_buffer.handle,
		&requirements,
	)

	out_buffer.memory_index = v_context.find_memory_index_proc(
		requirements.memoryTypeBits,
		out_buffer.memory_property_flags,
	)
	if out_buffer.memory_index == -1 {
		log_error(
			"Unable to create vulkan buffer because the required memory type index was not found.",
		)
		return false
	}

	allocate_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = requirements.size,
		memoryTypeIndex = u32(out_buffer.memory_index),
	}

	res = vk.AllocateMemory(
		v_context.device.logical_device,
		&allocate_info,
		v_context.allocator,
		&out_buffer.memory,
	)
	if res != vk.Result.SUCCESS {
		log_error(
			"Unable to create vulkan buffer because the required memory allocation failed. Error: %d",
			int(res),
		)
		return false
	}

	if bind_on_create {
		vulkan_buffer_bind(v_context, out_buffer, 0)
	}

	return true
}

vulkan_buffer_destroy :: proc(v_context: ^vulkan_context, buffer: ^vulkan_buffer) {
	if buffer.memory != 0 {
		vk.FreeMemory(v_context.device.logical_device, buffer.memory, v_context.allocator)
		buffer.memory = 0
	}
	if buffer.handle != vk.Buffer(0) {
		vk.DestroyBuffer(v_context.device.logical_device, buffer.handle, v_context.allocator)
		buffer.handle = vk.Buffer(0)
	}

	buffer.total_size = 0
	buffer.usage = nil
	buffer.is_locked = false
}

vulkan_buffer_resize :: proc(
	v_context: ^vulkan_context,
	new_size: u64,
	buffer: ^vulkan_buffer,
	queue: vk.Queue,
	pool: vk.CommandPool,
) -> b8 {
	buffer_info := vk.BufferCreateInfo {
		sType       = .BUFFER_CREATE_INFO,
		size        = vk.DeviceSize(new_size),
		usage       = buffer.usage,
		sharingMode = .EXCLUSIVE,
	}

	new_buffer: vk.Buffer
	res := vk.CreateBuffer(
		v_context.device.logical_device,
		&buffer_info,
		v_context.allocator,
		&new_buffer,
	)
	if res != vk.Result.SUCCESS {
		return false
	}

	requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(v_context.device.logical_device, new_buffer, &requirements)

	allocate_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = requirements.size,
		memoryTypeIndex = u32(buffer.memory_index),
	}

	new_memory: vk.DeviceMemory
	res = vk.AllocateMemory(
		v_context.device.logical_device,
		&allocate_info,
		v_context.allocator,
		&new_memory,
	)
	if res != vk.Result.SUCCESS {
		// log_error("Unable to resize vulkan buffer because the required memory allocation failed. Error: %d", int(res))
		return false
	}

	res = vk.BindBufferMemory(v_context.device.logical_device, new_buffer, new_memory, 0)
	if res != vk.Result.SUCCESS {
		return false
	}

	// Copy old -> new
	vulkan_buffer_copy_to(
		v_context,
		pool,
		vk.Fence(0),
		queue,
		buffer.handle,
		0,
		new_buffer,
		0,
		buffer.total_size,
	)
	_ = vk.DeviceWaitIdle(v_context.device.logical_device)

	// Destroy old resources
	if buffer.memory != 0 {
		vk.FreeMemory(v_context.device.logical_device, buffer.memory, v_context.allocator)
		buffer.memory = 0
	}
	if buffer.handle != 0 {
		vk.DestroyBuffer(v_context.device.logical_device, buffer.handle, v_context.allocator)
		buffer.handle = 0
	}

	// Update
	buffer.total_size = new_size
	buffer.memory = new_memory
	buffer.handle = new_buffer

	return true
}

vulkan_buffer_bind :: proc(v_context: ^vulkan_context, buffer: ^vulkan_buffer, offset: u64) {
	res := vk.BindBufferMemory(
		v_context.device.logical_device,
		buffer.handle,
		buffer.memory,
		vk.DeviceSize(offset),
	)
	if res != vk.Result.SUCCESS {
		log_error("FAILED TO BIND A VULKAN BUFFER")
	}
}

vulkan_buffer_lock_memory :: proc(
	v_context: ^vulkan_context,
	buffer: ^vulkan_buffer,
	offset: u64,
	size: u64,
	flags: vk.MemoryMapFlags,
) -> rawptr {
	data: rawptr
	res := vk.MapMemory(
		v_context.device.logical_device,
		buffer.memory,
		vk.DeviceSize(offset),
		vk.DeviceSize(size),
		flags,
		&data,
	)
	if res != vk.Result.SUCCESS {
		log_error("Failed to log buffer memory!!!")
	}
	return data
}

vulkan_buffer_unlock_memory :: proc(v_context: ^vulkan_context, buffer: ^vulkan_buffer) {
	vk.UnmapMemory(v_context.device.logical_device, buffer.memory)
}

vulkan_buffer_load_data :: proc(
	v_context: ^vulkan_context,
	buffer: ^vulkan_buffer,
	offset: u64,
	size: u64,
	flags: vk.MemoryMapFlags,
	data: rawptr,
) {
	data_ptr: rawptr
	res := vk.MapMemory(
		v_context.device.logical_device,
		buffer.memory,
		vk.DeviceSize(offset),
		vk.DeviceSize(size),
		flags,
		&data_ptr,
	)
	if res != vk.Result.SUCCESS {
		log_error("Failed to map buffer memory")
	}
	mem.copy(data_ptr, data, int(size))
	vk.UnmapMemory(v_context.device.logical_device, buffer.memory)
}

vulkan_buffer_copy_to :: proc(
	v_context: ^vulkan_context,
	pool: vk.CommandPool,
	fence: vk.Fence,
	queue: vk.Queue,
	source: vk.Buffer,
	source_offset: u64,
	dest: vk.Buffer,
	dest_offset: u64,
	size: u64,
) {
	_ = vk.QueueWaitIdle(queue)

	temp_command_buffer: vulkan_command_buffer
	vulkan_command_buffer_allocate_and_begin_single_use(v_context, pool, &temp_command_buffer)

	copy_region := vk.BufferCopy {
		srcOffset = vk.DeviceSize(source_offset),
		dstOffset = vk.DeviceSize(dest_offset),
		size      = vk.DeviceSize(size),
	}

	vk.CmdCopyBuffer(temp_command_buffer.handle, source, dest, 1, &copy_region)

	vulkan_command_buffer_end_single_use(v_context, pool, &temp_command_buffer, queue)
}

