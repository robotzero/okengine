package core

import c "../containers"

texture_system_config :: struct {
	max_texture_count: u32,
}

texture_system_state :: struct {
	config:                   texture_system_config,
	default_texture:          texture,
	registered_textures:      [dynamic]texture,
	registered_texture_table: c.hashtable,
}

texture_reference :: struct {
	reference_count: u64,
	handle:          u32,
	auto_release:    bool,
}

DEFAULT_TEXTURE_NAME :: "default"

@(private = "file")
state_ptr: ^texture_system_state

