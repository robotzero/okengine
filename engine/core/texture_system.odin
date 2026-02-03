package core

import c "../containers"
import "core:fmt"
import "core:strings"
import si "vendor:stb/image"

texture_system_config :: struct {
	max_texture_count: u32,
}

texture_system_state :: struct {
	config:                   texture_system_config,
	default_texture:          texture,
	registered_textures:      ^texture,
	registered_texture_table: c.hashtable(texture_reference, MAX_TEXTURE_COUNT),
}

texture_reference :: struct {
	reference_count: u64,
	handle:          u32,
	auto_release:    bool,
}

MAX_TEXTURE_COUNT :: 65536

@(private = "file")
state_ptr: ^texture_system_state

