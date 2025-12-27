package core

import arr "../containers"
import vk "vendor:vulkan"

vulkan_command_buffer_allocate :: proc(
	v_context: ^vulkan_context,
	pool: vk.CommandPool,
	is_primary: bool,
	out_command_buffer: ^vulkan_command_buffer,
) {
	allocate_info: vk.CommandBufferAllocateInfo = {
		sType              = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool        = pool,
		level              = is_primary ? vk.CommandBufferLevel.PRIMARY : vk.CommandBufferLevel.SECONDARY,
		commandBufferCount = 1,
		pNext              = nil,
	}

	out_command_buffer.state = vulkan_command_buffer_state.COMMAND_BUFFER_STATE_NOT_ALLOCATED
	assert(
		vk.AllocateCommandBuffers(
			v_context.device.logical_device,
			&allocate_info,
			&out_command_buffer.handle,
		) ==
		vk.Result.SUCCESS,
	)
	out_command_buffer.state = vulkan_command_buffer_state.COMMAND_BUFFER_STATE_READY
}

vulkan_command_buffer_free :: proc(
	v_context: ^vulkan_context,
	pool: vk.CommandPool,
	command_buffer: ^vulkan_command_buffer,
) {

	vk.FreeCommandBuffers(v_context.device.logical_device, pool, 1, &command_buffer.handle)

	command_buffer.handle = nil
	command_buffer.state = vulkan_command_buffer_state.COMMAND_BUFFER_STATE_NOT_ALLOCATED
}

vulkan_command_buffer_begin :: proc(
	command_buffer: ^vulkan_command_buffer,
	is_single_use: bool,
	is_renderpass_continue: bool,
	is_simultaneous_use: bool,
) {
	begin_info: vk.CommandBufferBeginInfo = {
		sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO,
		flags = {},
	}

	if is_single_use {
		begin_info.flags |= {.ONE_TIME_SUBMIT}
	}

	if is_renderpass_continue {
		begin_info.flags |= {.RENDER_PASS_CONTINUE}
	}

	if is_simultaneous_use {
		begin_info.flags |= {.SIMULTANEOUS_USE}
	}

	assert(vk.BeginCommandBuffer(command_buffer.handle, &begin_info) == vk.Result.SUCCESS)
	command_buffer.state = vulkan_command_buffer_state.COMMAND_BUFFER_STATE_RECORDING
}

vulkan_command_buffer_end :: proc(command_buffer: ^vulkan_command_buffer) {
	assert(vk.EndCommandBuffer(command_buffer.handle) == vk.Result.SUCCESS)
	command_buffer.state = vulkan_command_buffer_state.COMMAND_BUFFER_STATE_RECORDING_ENDED
}

vulkan_command_buffer_update_submitted :: proc(command_buffer: ^vulkan_command_buffer) {
	command_buffer.state = vulkan_command_buffer_state.COMMAND_BUFFER_STATE_SUBMITTED
}

vulkan_command_buffer_reset :: proc(command_buffer: ^vulkan_command_buffer) {
	command_buffer.state = vulkan_command_buffer_state.COMMAND_BUFFER_STATE_READY
}

vulkan_command_buffer_allocate_and_begin_single_use :: proc(
	v_context: ^vulkan_context,
	pool: vk.CommandPool,
	out_command_buffer: ^vulkan_command_buffer,
) {
	vulkan_command_buffer_allocate(v_context, pool, true, out_command_buffer)
	vulkan_command_buffer_begin(out_command_buffer, true, false, false)
}

vulkan_command_buffer_end_single_use :: proc(
	v_context: ^vulkan_context,
	pool: vk.CommandPool,
	command_buffer: ^vulkan_command_buffer,
	queue: vk.Queue,
) {
	// End the command buffer.
	vulkan_command_buffer_end(command_buffer)

	// Submit queue
	submit_info: vk.SubmitInfo = {
		sType              = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers    = &command_buffer.handle,
	}

	assert(vk.QueueSubmit(queue, 1, &submit_info, 0) == vk.Result.SUCCESS)

	// Wait for it to finish
	assert(vk.QueueWaitIdle(queue) == vk.Result.SUCCESS)

	// Free the command buffer
	vulkan_command_buffer_free(v_context, pool, command_buffer)
}

