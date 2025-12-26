package core

import vk "vendor:vulkan"

BUILDIN_SHADER_NAME_OBJECT :: "Builtin.ObjectShader"

vulkan_object_shader_create :: proc(
	v_context: ^vulkan_context,
	out_shader: ^vulkan_object_shader,
) -> bool {

	// Shader module init per stage.
	stage_type_strs: [OBJECT_SHADER_STAGE_COUNT]string = {"vert", "frag"}
	stage_types: [OBJECT_SHADER_STAGE_COUNT]vk.ShaderStageFlags = {{.VERTEX}, {.FRAGMENT}}

	for i in 0 ..< OBJECT_SHADER_STAGE_COUNT {
		if !create_shader_module(
			v_context,
			BUILDIN_SHADER_NAME_OBJECT,
			stage_type_strs[i],
			stage_types[i],
			cast(u32)i,
			&out_shader.stages,
		) {
			return false
		}
	}
	return true
}

