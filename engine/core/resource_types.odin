package core

import "../okmath"

TEXTURE_NAME_MAX_LENGTH :: 512
MATERIAL_NAME_MAX_LENGTH :: 256

texture_use :: enum {
	TEXTURE_USE_UNKNOWN     = 0x00,
	TEXTURE_USE_MAP_DIFFUSE = 0x01,
}

texture_map :: struct {
	texture: ^texture,
	use:     texture_use,
}

material :: struct {
	id:             u32,
	generation:     u32,
	internal_id:    u32,
	name:           string,
	diffuse_colour: okmath.vec4,
	diffuse_map:    texture_map,
}
texture :: struct {
	id:               u32,
	width:            u32,
	height:           u32,
	channel_count:    u8,
	has_transparency: bool,
	generation:       u32,
	internal_data:    ^vulkan_texture_data,
	name:             string,
}

