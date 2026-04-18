package systems

import c "../containers"
import k "../kstring"
import l "../logger"
import ren "../renderer"
import r "../resources"
import "core:strings"

texture_system_config :: struct {
	max_texture_count: u32,
}

texture_system_state :: struct {
	config:                   texture_system_config,
	default_texture:          r.texture,
	default_specular_texture: r.texture,
	default_normal_texture:   r.texture,
	registered_textures:      []r.texture,
	registered_texture_table: ^c.hashtable(texture_reference),
}

texture_reference :: struct {
	reference_count: u64,
	handle:          u32,
	auto_release:    bool,
}

DEFAULT_TEXTURE_NAME :: "default"
MAX_TEXTURE_COUNT :: 65536

@(private = "file")
state_ptr: ^texture_system_state

texture_system_initialize :: proc(
	state: ^texture_system_state,
	config: texture_system_config,
	allocator := context.allocator,
) -> b8 {
	if config.max_texture_count == 0 {
		l.log_fatal("texture_system_initialize - config.max_texture_count must be > 0.")
		return false
	}

	if state == nil {
		return true
	}

	state_ptr = state
	state_ptr.config = config
	//@MEMORY use containers so that we can tag the memory
	state_ptr.registered_textures = make([]r.texture, MAX_TEXTURE_COUNT, allocator)

	//@MEMORY use containers to that we can tag memory
	hashtable_var := new(c.hashtable(texture_reference), allocator)
	c.hashtable_create(
		size_of(texture_reference),
		config.max_texture_count,
		false,
		hashtable_var,
		nil,
		nil,
		allocator,
	)

	// Fill the hashtable with invalid references to use as a default.
	invalid_ref := texture_reference {
		auto_release    = false,
		handle          = r.INVALID_ID, // Primary reason for needing default values.
		reference_count = 0,
	}
	state_ptr.registered_texture_table = hashtable_var
	c.hashtable_fill(state_ptr.registered_texture_table, invalid_ref)

	// Invalidate all textures in the array.
	for i in 0 ..< state_ptr.config.max_texture_count {
		state_ptr.registered_textures[i].id = r.INVALID_ID
		state_ptr.registered_textures[i].generation = r.INVALID_ID
	}

	// Create default textures for use in the system.
	create_default_textures(state_ptr)

	return true
}

texture_system_shutdown :: proc() {
	if state_ptr != nil {
		// Destroy all loaded textures.
		for i in 0 ..< state_ptr.config.max_texture_count {
			t := &state_ptr.registered_textures[i]
			if t.generation != r.INVALID_ID {
				ren.renderer_destroy_texture(t)
			}
		}

		destroy_default_textures(state_ptr)
		// free(state_ptr.registered_texture_table)

		state_ptr = nil
	}
}

texture_system_acquire :: proc(name: string, auto_release: bool) -> ^r.texture {
	// Return default texture, but warn about it since this should be returned via get_default_texture();
	if strings.equal_fold(name, DEFAULT_TEXTURE_NAME) {
		l.log_warning(
			"texture_system_acquire called for default texture. Use texture_system_get_default_texture for texture 'default'.",
		)
		return &state_ptr.default_texture
	}

	ref: texture_reference
	if state_ptr != nil && c.hashtable_get(state_ptr.registered_texture_table, name, &ref) {
		// This can only be changed the first time a texture is loaded.
		if ref.reference_count == 0 {
			ref.auto_release = auto_release
		}
		ref.reference_count += 1
		if ref.handle == r.INVALID_ID {
			// This means no texture exists here. Find a free index first.
			t: ^r.texture = nil
			for i in 0 ..< state_ptr.config.max_texture_count {
				if state_ptr.registered_textures[i].id == r.INVALID_ID {
					// A free slot has been found. Use its index as the handle.
					ref.handle = i
					t = &state_ptr.registered_textures[i]
					break
				}
			}

			// Make sure an empty slot was actually found.
			if t == nil || ref.handle == r.INVALID_ID {
				l.log_fatal(
					"texture_system_acquire - Texture system cannot hold anymore textures. Adjust configuration to allow more.",
				)
				return nil
			}

			// Create new texture.
			if !load_texture(name, t) {
				l.log_error("Failed to load texture '%s'.", name)
				return nil
			}

			// Also use the handle as the texture id.
			t.id = ref.handle
			l.log_debug(
				"Texture '%s' does not yet exist. Created, and ref_count is now %i.",
				name,
				ref.reference_count,
			)
		} else {
			l.log_debug(
				"Texture '%s' already exists, ref_count increased to %i.",
				name,
				ref.reference_count,
			)
		}

		// Update the entry.
		c.hashtable_set(state_ptr.registered_texture_table, name, ref)
		return &state_ptr.registered_textures[ref.handle]
	}

	// NOTE: This would only happen in the event something went wrong with the state.
	l.log_error(
		"texture_system_acquire failed to acquire texture '%s'. Null pointer will be returned.",
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
	if state_ptr != nil && c.hashtable_get(state_ptr.registered_texture_table, name, &ref) {
		if ref.reference_count == 0 {
			l.log_warning("Tried to release non-existent texture: '%s'", name)
			return
		}
		// Take a copy of the name since it will be wiped out by destroy
		name_copy := k.string_ncopy(name, r.TEXTURE_NAME_MAX_LENGTH)
		ref.reference_count -= 1
		if ref.reference_count == 0 && ref.auto_release {
			t := &state_ptr.registered_textures[ref.handle]

			destroy_texture(t)

			// Reset the reference.
			ref.handle = r.INVALID_ID
			ref.auto_release = false
			l.log_debug(
				"Released texture '%s'., Texture unloaded because reference count=0 and auto_release=true.",
				name_copy,
			)
		} else {
			l.log_debug(
				"Released texture '%s', now has a reference count of '%i' (auto_release=%s).",
				name_copy,
				ref.reference_count,
				ref.auto_release,
			)
		}

		// Update the entry.
		c.hashtable_set(state_ptr.registered_texture_table, name_copy, ref)
	} else {
		l.log_error("texture_system_release failed to release texture '%s'.", name)
	}
}

texture_system_get_default_texture :: proc() -> ^r.texture {
	if state_ptr != nil {
		return &state_ptr.default_texture
	}

	l.log_error(
		"texture_system_get_default_texture called before texture system initialization! Null pointer returned.",
	)
	return nil
}

texture_system_get_default_specular_texture :: proc() -> ^r.texture {
	if state_ptr != nil {
		return &state_ptr.default_specular_texture
	}

	l.log_error(
		"texture_system_get_default_specular_texture called before texture system initialization! Null pointer returned.",
	)
	return nil
}

texture_system_get_default_normal_texture :: proc() -> ^r.texture {
	if state_ptr != nil {
		return &state_ptr.default_normal_texture
	}

	l.log_error(
		"texture_system_get_default_normal_texture called before texture system initialization! Null pointer returned.",
	)
	return nil
}

create_default_textures :: proc(state: ^texture_system_state) -> b8 {
	// NOTE: Create default texture, a 256x256 blue/white checkerboard pattern.
	// This is done in code to eliminate asset dependencies.
	l.log_debug("Creating default texture...")
	tex_dimension :: 256
	channels :: 4
	pixel_count :: tex_dimension * tex_dimension
	pixels: [pixel_count * channels]u8
	// kset_memory(&pixels[0], 255, int(size_of(pixels)))

	// Each pixel.
	for row in 0 ..< u32(tex_dimension) {
		for col in 0 ..< u32(tex_dimension) {
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
	state.default_texture.name = k.string_ncopy(DEFAULT_TEXTURE_NAME, r.TEXTURE_NAME_MAX_LENGTH)
	state.default_texture.width = tex_dimension
	state.default_texture.height = tex_dimension
	state.default_texture.channel_count = 4
	state.default_texture.generation = r.INVALID_ID
	state.default_texture.has_transparency = false
	ren.renderer_create_texture(pixels_slice, &state.default_texture)
	// Manually set the texture generation to invalid since this is a default texture.
	state.default_texture.generation = r.INVALID_ID

	// Default specular texture: solid white (full specular reflection).
	l.log_debug("Creating default specular texture...")
	spec_pixels: [pixel_count * channels]u8
	for i in 0 ..< pixel_count * channels {
		spec_pixels[i] = 255
	}
	spec_slice := spec_pixels[:]
	state.default_specular_texture.name = k.string_ncopy("default_spec", r.TEXTURE_NAME_MAX_LENGTH)
	state.default_specular_texture.width = tex_dimension
	state.default_specular_texture.height = tex_dimension
	state.default_specular_texture.channel_count = 4
	state.default_specular_texture.generation = r.INVALID_ID
	state.default_specular_texture.has_transparency = false
	ren.renderer_create_texture(spec_slice, &state.default_specular_texture)
	state.default_specular_texture.generation = r.INVALID_ID

	// Default normal texture: flat normal pointing in +Z (tangent space).
	// RGB = (0, 0, 255, 255) — decoded as normal (0, 0, 1) meaning no perturbation.
	l.log_debug("Creating default normal texture...")
	norm_pixels: [16 * 16 * 4]u8
	for row in 0 ..< 16 {
		for col in 0 ..< 16 {
			index := (row * 16 + col) * 4
			norm_pixels[index + 0] = 128 // R = x
			norm_pixels[index + 1] = 128 // G = y
			norm_pixels[index + 2] = 255 // B = z (pointing straight out)
			norm_pixels[index + 3] = 255 // A
		}
	}
	norm_slice := norm_pixels[:]
	state.default_normal_texture.name = k.string_ncopy("default_NORM", r.TEXTURE_NAME_MAX_LENGTH)
	state.default_normal_texture.width = 16
	state.default_normal_texture.height = 16
	state.default_normal_texture.channel_count = 4
	state.default_normal_texture.generation = r.INVALID_ID
	state.default_normal_texture.has_transparency = false
	ren.renderer_create_texture(norm_slice, &state.default_normal_texture)
	state.default_normal_texture.generation = r.INVALID_ID

	return true
}

destroy_default_textures :: proc(state: ^texture_system_state) {
	if state != nil {
		destroy_texture(&state.default_texture)
		destroy_texture(&state.default_specular_texture)
		destroy_texture(&state.default_normal_texture)
	}
}

load_texture :: proc(texture_name: string, t: ^r.texture) -> b8 {
	img_resource: r.resource
	if !resource_system_load(texture_name, .IMAGE, &img_resource) {
		l.log_error("Failed to load image resource for texture '%s'", texture_name)
		return false
	}

	resource_data := img_resource.data.(r.image_resource_data)

	// Use a temporary texture to load into.
	temp_texture: r.texture
	temp_texture.width = resource_data.width
	temp_texture.height = resource_data.height
	temp_texture.channel_count = resource_data.channel_count

	current_generation := t.generation
	t.generation = r.INVALID_ID

	total_size: u64 =
		u64(temp_texture.width) * u64(temp_texture.height) * u64(temp_texture.channel_count)

	// Check for transparency
	has_transparency := false
	for i: u64 = 0; i < total_size; i += u64(temp_texture.channel_count) { // non-unit stride, keep C-style
		a := resource_data.pixels[i + 3]
		if a < 255 {
			has_transparency = true
			break
		}
	}

	// Take a copy of the name.
	temp_texture.name = k.string_ncopy(texture_name, r.TEXTURE_NAME_MAX_LENGTH)
	temp_texture.generation = r.INVALID_ID
	temp_texture.has_transparency = has_transparency

	// Acquire internal texture resources and upload to GPU.
	pixels_slice := resource_data.pixels[:int(total_size)]
	ren.renderer_create_texture(pixels_slice, &temp_texture)

	// Take a copy of the old texture.
	old := t^

	// Assign the temp texture to the pointer.
	t^ = temp_texture

	// Destroy the old texture.
	ren.renderer_destroy_texture(&old)

	if current_generation == r.INVALID_ID {
		t.generation = 0
	} else {
		t.generation = current_generation + 1
	}

	// Clean up data.
	resource_system_unload(&img_resource)
	return true
}

destroy_texture :: proc(t: ^r.texture) {
	ren.renderer_destroy_texture(t)
	t.id = r.INVALID_ID
	t.generation = r.INVALID_ID
}
