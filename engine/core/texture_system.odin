package core

import c "../containers"
import "core:fmt"
import "core:mem"
import "core:strings"
import si "vendor:stb/image"

texture_system_config :: struct {
	max_texture_count: u32,
}

texture_system_state :: struct {
	config:                   texture_system_config,
	default_texture:          texture,
	registered_textures:      [dynamic]texture,
	registered_texture_table: ^c.hashtable(texture_reference, MAX_TEXTURE_COUNT),
}

texture_reference :: struct {
	reference_count: u64,
	handle:          u32,
	auto_release:    bool,
}

MAX_TEXTURE_COUNT :: 65536

@(private = "file")
state_ptr: ^texture_system_state

create_default_textures :: proc(state: ^texture_system_state) -> b8
destroy_default_textures :: proc(state: ^texture_system_state)
load_texture :: proc(texture_name: string, t: ^texture) -> b8

texture_system_initialize :: proc(
	state: ^texture_system_state,
	config: texture_system_config,
	sys_allocator: ^mem.Allocator,
) -> b8 {
	if config.max_texture_count == 0 {
		log_fatal("texture_system_initialize - config.max_texture_count must be > 0.")
		return false
	}

	// Block of memory will contain state structure, then block for array, then block for hashtable.
	// struct_requirement: u64 = size_of(texture_system2_state)
	// array_requirement: u64 = size_of(texture) * u64(config.max_texture_count)
	// hashtable_requirement: u64 = size_of(texture_reference2) * u64(config.max_texture_count)
	// memory_requirement^ = struct_requirement + array_requirement + hashtable_requirement

	if state == nil {
		return true
	}

	state_ptr = state
	state_ptr.config = config
	state_ptr.registered_textures = make([dynamic]texture, sys_allocator)

	hashtable_var := c.hashtable(texture_reference, MAX_TEXTURE_COUNT)
	hashtable_memory := [MAX_TEXTURE_COUNT]texture_reference{}

	// Create a hashtable for texture lookups.
	c.hashtable_create(
		size_of(texture_reference),
		config.max_texture_count,
		false,
		&hashtable_var,
		texture_reference,
		hashtable_memory,
	)

	// Fill the hashtable with invalid references to use as a default.
	invalid_ref: texture_reference
	invalid_ref.auto_release = false
	invalid_ref.handle = INVALID_ID // Primary reason for needing default values.
	invalid_ref.reference_count = 0
	state_ptr.registered_texture_table = &hashtable_var
	c.hashtable_fill(&state_ptr.registered_texture_table, texture_reference, &invalid_ref)

	// Invalidate all textures in the array.
	for i: u32 = 0; i < state_ptr.config.max_texture_count; i += 1 {
		state_ptr.registered_textures[i].id = INVALID_ID
		state_ptr.registered_textures[i].generation = INVALID_ID
	}

	// Create default textures for use in the system.
	create_default_textures(state_ptr)

	return true
}

texture_system_shutdown :: proc() {
	if state_ptr != nil {
		// Destroy all loaded textures.
		for i: u32 = 0; i < state_ptr.config.max_texture_count; i += 1 {
			t := &state_ptr.registered_textures[i]
			if t.generation != INVALID_ID {
				renderer_destroy_texture(t)
			}
		}

		destroy_default_textures(state_ptr)

		state_ptr = nil
	}
}

texture_system_acquire :: proc(name: string, auto_release: b8) -> ^texture {
	// Return default texture, but warn about it since this should be returned via get_default_texture();
	if strings.equal_fold(name, DEFAULT_TEXTURE_NAME) {
		log_warning(
			"texture_system_acquire called for default texture. Use texture_system2_get_default_texture for texture 'default'.",
		)
		return &state_ptr.default_texture
	}

	ref: texture_reference
	if state_ptr != nil && c.hashtable_get(&state_ptr.registered_texture_table, name, &ref) {
		// This can only be changed the first time a texture is loaded.
		if ref.reference_count == 0 {
			ref.auto_release = auto_release
		}
		ref.reference_count += 1
		if ref.handle == INVALID_ID {
			// This means no texture exists here. Find a free index first.
			t: ^texture = nil
			for i: u32 = 0; i < state_ptr.config.max_texture_count; i += 1 {
				if state_ptr.registered_textures[i].id == INVALID_ID {
					// A free slot has been found. Use its index as the handle.
					ref.handle = i
					t = &state_ptr.registered_textures[i]
					break
				}
			}

			// Make sure an empty slot was actually found.
			if t == nil || ref.handle == INVALID_ID {
				log_fatal(
					"texture_system2_acquire - Texture system cannot hold anymore textures. Adjust configuration to allow more.",
				)
				return nil
			}

			// Create new texture.
			if !load_texture(name, t) {
				log_error("Failed to load texture '%s'.", name)
				return nil
			}

			// Also use the handle as the texture id.
			t.id = ref.handle
			log_debug(
				"Texture '%s' does not yet exist. Created, and ref_count is now %i.",
				name,
				ref.reference_count,
			)
		} else {
			log_debug(
				"Texture '%s' already exists, ref_count increased to %i.",
				name,
				ref.reference_count,
			)
		}

		// Update the entry.
		hashtable_set(&state_ptr.registered_texture_table, name, &ref)
		return &state_ptr.registered_textures[ref.handle]
	}

	// NOTE: This would only happen in the event something went wrong with the state.
	log_error(
		"texture_system2_acquire failed to acquire texture '%s'. Null pointer will be returned.",
		name,
	)
	return nil
}

texture_system_release :: proc(name: string) {
	// Ignore release requests for the default texture.
	if strings.equal_fold(name, DEFAULT_TEXTURE_NAME) {
		return
	}
	ref: texture_reference
	if state_ptr != nil && c.hashtable_get(&state_ptr.registered_texture_table, name, &ref) {
		if ref.reference_count == 0 {
			log_warning("Tried to release non-existent texture: '%s'", name)
			return
		}
		ref.reference_count -= 1
		if ref.reference_count == 0 && ref.auto_release {
			t := &state_ptr.registered_textures[ref.handle]

			// Release texture.
			renderer_destroy_texture(t)

			// Reset the array entry, ensure invalid ids are set.
			kzero_memory(t, size_of(texture))
			t.id = INVALID_ID
			t.generation = INVALID_ID

			// Reset the reference.
			ref.handle = INVALID_ID
			ref.auto_release = false
			log_debug(
				"Released texture '%s'., Texture unloaded because reference count=0 and auto_release=true.",
				name,
			)
		} else {
			log_debug(
				"Released texture '%s', now has a reference count of '%i' (auto_release=%s).",
				name,
				ref.reference_count,
				ref.auto_release,
			)
		}

		// Update the entry.
		c.hashtable_set(&state_ptr.registered_texture_table, name, &ref)
	} else {
		log_error("texture_system2_release failed to release texture '%s'.", name)
	}
}

texture_system_get_default_texture :: proc() -> ^texture {
	if state_ptr != nil {
		return &state_ptr.default_texture
	}

	log_error(
		"texture_system2_get_default_texture called before texture system initialization! Null pointer returned.",
	)
	return nil
}

create_default_textures :: proc(state: ^texture_system_state) -> b8 {
	// NOTE: Create default texture, a 256x256 blue/white checkerboard pattern.
	// This is done in code to eliminate asset dependencies.
	log_debug("Creating default texture...")
	tex_dimension: u32 = 256
	channels: u32 = 4
	pixel_count: u32 = tex_dimension * tex_dimension
	pixels: [pixel_count * channels]u8
	kset_memory(&pixels[0], 255, int(size_of(pixels)))

	// Each pixel.
	for row: u32 = 0; row < tex_dimension; row += 1 {
		for col: u32 = 0; col < tex_dimension; col += 1 {
			index := row * tex_dimension + col
			index_bpp := index * channels
			if (row % 2) != 0 {
				if (col % 2) != 0 {
					pixels[index_bpp + 0] = 0
					pixels[index_bpp + 1] = 0
				}
			} else {
				if (col % 2) == 0 {
					pixels[index_bpp + 0] = 0
					pixels[index_bpp + 1] = 0
				}
			}
		}
	}
	pixels_slice := pixels[:]
	renderer_create_texture(
		DEFAULT_TEXTURE_NAME,
		false,
		cast(i32)tex_dimension,
		cast(i32)tex_dimension,
		4,
		&pixels_slice,
		false,
		&state.default_texture,
	)
	// Manually set the texture generation to invalid since this is a default texture.
	state.default_texture.generation = INVALID_ID

	return true
}

destroy_default_textures :: proc(state: ^texture_system_state) {
	if state != nil {
		renderer_destroy_texture(&state.default_texture)
	}
}

load_texture :: proc(texture_name: string, t: ^texture) -> b8 {
	// TODO: Should be able to be located anywhere.
	required_channel_count: i32 = 4
	si.set_flip_vertically_on_load(1)
	full_file_path := fmt.aprintf("assets/textures/%s.%s", texture_name, "png")
	defer delete(full_file_path)

	// Use a temporary texture to load into.
	temp_texture: texture

	width_i32: i32
	height_i32: i32
	channels_i32: i32
	data := si.load(
		raw_data(full_file_path),
		&width_i32,
		&height_i32,
		&channels_i32,
		required_channel_count,
	)

	temp_texture.width = u32(width_i32)
	temp_texture.height = u32(height_i32)
	temp_texture.channel_count = u8(required_channel_count)

	if data != nil {
		current_generation := t.generation
		t.generation = INVALID_ID

		total_size: u64 =
			u64(temp_texture.width) * u64(temp_texture.height) * u64(required_channel_count)
		data_slice := ([^]u8)(data)[:int(total_size)]

		// Check for transparency
		has_transparency: b32 = false
		for i: u64 = 0; i < total_size; i += u64(required_channel_count) {
			a := data_slice[i + 3]
			if a < 255 {
				has_transparency = true
				break
			}
		}

		if si.failure_reason() != nil {
			log_warning(
				"load_texture2() failed to load file '%s': %s",
				full_file_path,
				si.failure_reason(),
			)
		}

		// Acquire internal texture resources and upload to GPU.
		pixels_slice := data_slice
		renderer_create_texture(
			cstring(texture_name),
			true,
			i32(temp_texture.width),
			i32(temp_texture.height),
			i32(temp_texture.channel_count),
			&pixels_slice,
			has_transparency,
			&temp_texture,
		)

		// Take a copy of the old texture.
		old := t^

		// Assign the temp texture to the pointer.
		t^ = temp_texture

		// Destroy the old texture.
		renderer_destroy_texture(&old)

		if current_generation == INVALID_ID {
			t.generation = 0
		} else {
			t.generation = current_generation + 1
		}

		// Clean up data.
		si.image_free(data)
		return true
	} else {
		if si.failure_reason() != nil {
			log_warning(
				"load_texture2() failed to load file '%s': %s",
				full_file_path,
				si.failure_reason(),
			)
		}
		return false
	}
}

