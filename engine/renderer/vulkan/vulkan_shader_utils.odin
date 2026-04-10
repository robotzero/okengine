package vulkan_renderer

import l "../../logger"
import res "../../resources"
import sys "../../systems"
import "core:fmt"
import "core:slice"
import vk "vendor:vulkan"

create_shader_module :: proc(
	v_context: ^vulkan_context,
	name: string,
	type_str: string,
	shader_stage_flag: vk.ShaderStageFlags,
	stage_index: u32,
	shader_stages: ^[MATERIAL_SHADER_STAGE_COUNT]vulkan_shader_stage,
) -> bool {
	// Build file name — the resource system prepends the asset base path.
	file_name := fmt.aprintf("shaders/%s.%s.spv", name, type_str)
	defer delete(file_name)

	// Read the resource.
	binary_resource: res.resource
	if !sys.resource_system_load(file_name, .BINARY, &binary_resource) {
		l.log_error("Unable to read shader module: %s.", file_name)
		return false
	}

	binary_data := binary_resource.data.(res.binary_resource_data)
	as_u32 := slice.reinterpret([]u32, binary_data.bytes)

	shader_stages[stage_index].create_info = vk.ShaderModuleCreateInfo {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(binary_data.bytes),
		pCode    = raw_data(as_u32),
	}

	must(
		vk.CreateShaderModule(
			v_context.device.logical_device,
			&shader_stages[stage_index].create_info,
			v_context.allocator,
			&shader_stages[stage_index].handle,
		),
	)

	// Release the resource.
	sys.resource_system_unload(&binary_resource)

	// Shader stage info
	shader_stages[stage_index].shader_stage_create_info = vk.PipelineShaderStageCreateInfo {
		sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage  = shader_stage_flag,
		module = shader_stages[stage_index].handle,
		pName  = "main",
	}

	return true
}

