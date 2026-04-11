package resources

import "../okmath"

INVALID_ID :: 4294967295

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
	CUSTOM,
}

// Type-safe resource data payload — replaces C's void* data field.
resource_data :: union {
	text_resource_data,
	binary_resource_data,
	image_resource_data,
	material_config,
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
	name:             string,
	type:             material_type,
	auto_release:     bool,
	diffuse_colour:   okmath.vec4,
	diffuse_map_name: string,
}

resource :: struct {
	loader_id: u32,
	name:      string,
	full_path: string,
	data:      resource_data,
}

material_type :: enum {
	MATERIAL_TYPE_WORLD = 0,
	MATERIAL_TYPE_UI    = 1,
}

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
	type:           material_type,
	name:           string,
	diffuse_colour: okmath.vec4,
	diffuse_map:    texture_map,
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

