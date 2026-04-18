package resources

import "../okmath"

INVALID_ID :: 4294967295
INVALID_ID_U16 :: 65535
INVALID_ID_U8 :: 255

TEXTURE_NAME_MAX_LENGTH :: 512
MATERIAL_NAME_MAX_LENGTH :: 256
GEOMETRY_NAME_MAX_LENGTH :: 256

// Pre-defined resource types.
resource_type :: enum {
	TEXT,
	BINARY,
	IMAGE,
	MATERIAL,
	STATIC_MESH,
	SHADER,
	CUSTOM,
}

// Type-safe resource data payload — replaces C's void* data field.
resource_data :: union {
	text_resource_data,
	binary_resource_data,
	image_resource_data,
	material_config,
	shader_config,
}

text_resource_data :: struct {
	text: string,
}

binary_resource_data :: struct {
	bytes: []u8,
}

image_resource_data :: struct {
	channel_count: u8,
	width:         u32,
	height:        u32,
	pixels:        [^]u8,
}

material_config :: struct {
	name:              string,
	shader_name:       string,
	auto_release:      bool,
	diffuse_colour:    okmath.vec4,
	shininess:         f32,
	diffuse_map_name:  string,
	specular_map_name: string,
	normal_map_name:   string,
}

resource :: struct {
	loader_id: u32,
	name:      string,
	full_path: string,
	data:      resource_data,
}

texture_use :: enum {
	TEXTURE_USE_UNKNOWN      = 0x00,
	TEXTURE_USE_MAP_DIFFUSE  = 0x01,
	TEXTURE_USE_MAP_SPECULAR = 0x02,
	TEXTURE_USE_MAP_NORMAL   = 0x03,
}

texture_map :: struct {
	texture: ^texture,
	use:     texture_use,
}

material :: struct {
	id:             u32,
	generation:     u32,
	internal_id:    u32,
	shader_id:      u32,
	name:           string,
	diffuse_colour: okmath.vec4,
	shininess:      f32,
	diffuse_map:    texture_map,
	specular_map:   texture_map,
	normal_map:     texture_map,
}

geometry :: struct {
	id:          u32,
	internal_id: u32,
	generation:  u32,
	name:        string,
	material:    ^material,
}

texture :: struct {
	id:               u32,
	width:            u32,
	height:           u32,
	channel_count:    u8,
	has_transparency: bool,
	generation:       u32,
	internal_data:    rawptr,
	name:             string,
}

// ── Shader types ──────────────────────────────────────────────────────────────

shader_stage :: enum u32 {
	VERTEX   = 0x00000001,
	GEOMETRY = 0x00000002,
	FRAGMENT = 0x00000004,
	COMPUTE  = 0x00000008,
}

shader_attribute_type :: enum u32 {
	FLOAT32   = 0,
	FLOAT32_2 = 1,
	FLOAT32_3 = 2,
	FLOAT32_4 = 3,
	MATRIX_4  = 4,
	INT8      = 5,
	UINT8     = 6,
	INT16     = 7,
	UINT16    = 8,
	INT32     = 9,
	UINT32    = 10,
}

shader_uniform_type :: enum u32 {
	FLOAT32   = 0,
	FLOAT32_2 = 1,
	FLOAT32_3 = 2,
	FLOAT32_4 = 3,
	INT8      = 4,
	UINT8     = 5,
	INT16     = 6,
	UINT16    = 7,
	INT32     = 8,
	UINT32    = 9,
	MATRIX_4  = 10,
	SAMPLER   = 11,
	CUSTOM    = 255,
}

shader_scope :: enum u32 {
	GLOBAL   = 0,
	INSTANCE = 1,
	LOCAL    = 2,
}

shader_attribute_config :: struct {
	name: string,
	size: u8,
	type: shader_attribute_type,
}

shader_uniform_config :: struct {
	name:     string,
	size:     u8,
	location: u32,
	type:     shader_uniform_type,
	scope:    shader_scope,
}

// Configuration for a shader, typically loaded from a .shadercfg file.
shader_config :: struct {
	name:             string,
	renderpass_name:  string,
	use_instances:    bool,
	use_local:        bool,
	stage_count:      u8,
	stages:           [dynamic]shader_stage,
	stage_names:      [dynamic]string,
	stage_filenames:  [dynamic]string,
	attribute_count:  u8,
	attributes:       [dynamic]shader_attribute_config,
	uniform_count:    u8,
	uniforms:         [dynamic]shader_uniform_config,
}

// A single attribute on a shader (runtime, after processing).
shader_attribute :: struct {
	name: string,
	size: u32,
	type: shader_attribute_type,
}

// A single uniform on a shader (runtime).
shader_uniform :: struct {
	offset:   u64,
	size:     u16,
	location: u16,
	index:    u16,
	set_index: u8,
	scope:    shader_scope,
	type:     shader_uniform_type,
}

// Runtime shader state.
shader_state :: enum {
	NOT_CREATED,
	UNINITIALIZED,
	INITIALIZED,
}

shader_push_constant_range :: struct {
	offset: u64,
	size:   u64,
}

// The frontend shader object managed by the shader_system.
shader :: struct {
	id:                        u32,
	name:                      string,
	use_instances:             bool,
	use_locals:                bool,
	required_ubo_alignment:    u64,
	global_ubo_size:           u64,
	global_ubo_stride:         u64,
	global_ubo_offset:         u64,
	ubo_size:                  u64,
	ubo_stride:                u64,
	push_constant_size:        u64,
	push_constant_stride:      u64,
	global_textures:           [dynamic]^texture,
	instance_texture_count:    u32,
	bound_instance_id:         u32,
	bound_ubo_offset:          u64,
	// Maps uniform name -> index into the uniforms array.
	uniform_lookup:            map[string]u16,
	uniforms:                  [dynamic]shader_uniform,
	attributes:                [dynamic]shader_attribute,
	state:                     shader_state,
	push_constant_range_count: u8,
	push_constant_ranges:      [32]shader_push_constant_range,
	attribute_stride:          u32,
	internal_data:             rawptr, // backend-specific (vulkan_shader*)
}

