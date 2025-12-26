package core

import pl "../platform/linux"
import "core:fmt"
import "core:os"
import "core:slice"
import vk "vendor:vulkan"

create_shader_module :: proc(
	v_context: ^vulkan_context,
	name: string,
	type_str: string,
	shader_stage_flag: vk.ShaderStageFlags,
	stage_index: u32,
	shader_stages: ^[OBJECT_SHADER_STAGE_COUNT]vulkan_shader_stage,
) -> bool {

	file_name := fmt.aprintf("bin/assets/shaders/%s.%s.spv", name, type_str)
	defer delete(file_name)
	// kzero_memory(shader_stages[stage_index].create_info, size_of(vk.ShaderModuleCreateInfo))
	shader_stages[stage_index].create_info.sType = vk.StructureType.SHADER_MODULE_CREATE_INFO

	handle, success := pl.filesystem_open(file_name, os.O_RDONLY)
	defer pl.filesystem_close(handle)
	if !success {
		return success
	}

	data := pl.file_system_read_all_bytes(handle)
	defer {
		if data != nil {
			delete(data)
			data = nil
		}
	}

	as_u32 := slice.reinterpret([]u32, data)

	shader_stages[stage_index].create_info.codeSize = len(data)
	shader_stages[stage_index].create_info.pCode = raw_data(as_u32)

	must(
		vk.CreateShaderModule(
			v_context.device.logical_device,
			&shader_stages[stage_index].create_info,
			v_context.allocator,
			&shader_stages[stage_index].handle,
		),
	)

	// Shader stage info
	kzero_memory(
		&shader_stages[stage_index].shader_stage_create_info,
		size_of(vk.PipelineShaderStageCreateInfo),
	)
	shader_stages[stage_index].shader_stage_create_info.sType =
		vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO
	shader_stages[stage_index].shader_stage_create_info.stage = shader_stage_flag
	shader_stages[stage_index].shader_stage_create_info.module = shader_stages[stage_index].handle
	shader_stages[stage_index].shader_stage_create_info.pName = "main"

	return true
}

