package core

import "../okmath"
import pl "../platform/linux"
import "core:fmt"
import "core:os"

DEFAULT_MATERIAL_NAME :: "default"

material_system_config :: struct {
	max_material_count: u32,
}

material_config :: struct {
	name:             string,
	auto_release:     bool,
	diffuse_colour:   okmath.vec4,
	diffuse_map_name: string,
}

material_system_state :: struct {
	config:                    material_system_config,
	default_material:          material,
	registered_materials:      []material,
	registered_material_table: ^hashtable,
}

material_reference :: struct {
	reference_count: u64,
	handle:          u32,
	auto_release:    bool,
}

@(private = "file")
state_ptr: ^material_system_state

material_system_initialize :: proc(
	state: ^material_system_state,
	config: material_system_config,
	allocator := context.allocator,
) -> b8 {
	if config.max_material_count == 0 {
		log_fatal("texture_system_initialize - config.max_texture_count must be > 0.")
		return false
	}
	if state == nil {
		return true
	}

	state_ptr = state
	state_ptr.config = config

	//@MEMORY use containers so that we can tag the memory
	state_ptr.registered_materials = make([]material, config.max_material_count, allocator)

	//@MEMORY use containers to that we can tag memory
	hashtable_var := new(hashtable, allocator)
	hashtable_memory := make([]material_reference, config.max_material_count, allocator)

	// Create a hashtable for texture lookups.
	hashtable_create(
		size_of(material_reference),
		config.max_material_count,
		false,
		hashtable_var,
		hashtable_memory,
		nil,
	)

	// Fill the hashtable with invalid references to use as a default.
	invalid_ref: material_reference
	invalid_ref.auto_release = false
	invalid_ref.handle = INVALID_ID // Primary reason for needing default values.
	invalid_ref.reference_count = 0
	state_ptr.registered_material_table = hashtable_var
	hashtable_fill(state_ptr.registered_material_table, material_reference, invalid_ref)

	// Invalidate all textures in the array.
	for i: u32 = 0; i < state_ptr.config.max_material_count; i += 1 {
		state_ptr.registered_materials[i].id = INVALID_ID
		state_ptr.registered_materials[i].generation = INVALID_ID
		state_ptr.registered_materials[i].internal_id = INVALID_ID
	}

	// Create default materials for use in the system.
	create_default_material(state_ptr)

	return true
}

material_system_shutdown :: proc() {
	if state_ptr != nil {
		// Destroy all loaded materials.
		for i: u32 = 0; i < state_ptr.config.max_material_count; i += 1 {
			s := &state_ptr.registered_materials[i]
			if s.id != INVALID_ID {
				destroy_material(s)
			}
		}

		destroy_material(&state_ptr.default_material)
		// free(state_ptr.registered_texture_table)

		state_ptr = nil
	}
}
material_system_acquire_from_config :: proc(config: material_config) -> ^material {
	// Return default material
	if strings_eqali(config.name, DEFAULT_MATERIAL_NAME) {
		return &state_ptr.default_material
	}

	ref: material_reference
	if state_ptr != nil &&
	   hashtable_get(state_ptr.registered_material_table, config.name, material_reference, &ref) {
		// This can only be changed the first time a material is loaded.
		if ref.reference_count == 0 {
			ref.auto_release = config.auto_release
		}
		ref.reference_count += 1
		if ref.handle == INVALID_ID {
			// This means no material exists here. Find a free index first.
			m: ^material = nil
			for i: u32 = 0; i < state_ptr.config.max_material_count; i += 1 {
				if state_ptr.registered_materials[i].id == INVALID_ID {
					// A free slot has been found. Use its index as the handle.
					ref.handle = i
					m = &state_ptr.registered_materials[i]
					break
				}
			}

			// Make sure an empty slot was actually found.
			if m == nil || ref.handle == INVALID_ID {
				log_fatal(
					"texture_system2_acquire - Texture system cannot hold anymore textures. Adjust configuration to allow more.",
				)
				return nil
			}

			// Create new texture.
			if !load_material(config, m) {
				log_error("Failed to load texture '%s'.", config.name)
				return nil
			}

			if m.generation == INVALID_ID {
				m.generation = 0
			} else {
				m.generation += 1
			}

			// Also use the handle as the texture id.
			m.id = ref.handle
			log_debug(
				"Texture '%s' does not yet exist. Created, and ref_count is now %i.",
				config.name,
				ref.reference_count,
			)
		} else {
			log_debug(
				"Texture '%s' already exists, ref_count increased to %i.",
				config.name,
				ref.reference_count,
			)
		}

		// Update the entry.
		hashtable_set(state_ptr.registered_material_table, config.name, ref)
		return &state_ptr.registered_materials[ref.handle]
	}

	// NOTE: This would only happen in the event something went wrong with the state.
	log_error(
		"texture_system2_acquire failed to acquire texture '%s'. Null pointer will be returned.",
		config.name,
	)
	return nil
}

material_system_release :: proc(name: string) {
	// Ignore release requests for the default texture.
	if strings_eqali(name, DEFAULT_MATERIAL_NAME) {
		return
	}
	ref: material_reference
	if state_ptr != nil &&
	   hashtable_get(state_ptr.registered_material_table, name, material_reference, &ref) {
		if ref.reference_count == 0 {
			log_warning("Tried to release non-existent texture: '%s'", name)
			return
		}
		ref.reference_count -= 1
		if ref.reference_count == 0 && ref.auto_release {
			m := &state_ptr.registered_materials[ref.handle]

			// Release texture.
			destroy_material(m)

			// Reset the array entry, ensure invalid ids are set.
			kzero_memory(m, size_of(material))

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
		hashtable_set(state_ptr.registered_material_table, name, ref)
	} else {
		log_error("texture_system2_release failed to release texture '%s'.", name)
	}
}

load_material :: proc(config: material_config, m: ^material) -> bool {
	m.name = string_ncopy(config.name, MATERIAL_NAME_MAX_LENGTH)
	m.diffuse_colour = config.diffuse_colour

	if len(config.diffuse_map_name) > 0 {
		m.diffuse_map.use = texture_use.TEXTURE_USE_MAP_DIFFUSE
		m.diffuse_map.texture = texture_system_acquire(config.diffuse_map_name, true)
		if m.diffuse_map.texture == nil {
			log_warning("Unable to load texture")
			m.diffuse_map.texture = texture_system_get_default_texture()
		}
	} else {
		m.diffuse_map.use = texture_use.TEXTURE_USE_UNKNOWN
		m.diffuse_map.texture = nil
	}

	// Sent it of to the renderer to acquire resources
	if !renderer_create_material(m) {
		log_error("Failed to acquire renderer resources for material '%s'", m.name)
		return false
	}

	return true
}

destroy_material :: proc(m: ^material) {
	log_debug("Destroying material '%s'", m.name)

	// Release texture references
	if m.diffuse_map.texture != nil {
		texture_system_release(m.diffuse_map.texture.name)
	}

	// Release renderer resources
	renderer_destroy_material(m)

	m.id = INVALID_ID
	m.generation = INVALID_ID
	m.internal_id = INVALID_ID
}

create_default_material :: proc(state: ^material_system_state) -> bool {
	state.default_material.id = INVALID_ID
	state.default_material.generation = INVALID_ID
	state.default_material.name = string_ncopy(DEFAULT_MATERIAL_NAME, MATERIAL_NAME_MAX_LENGTH)
	state.default_material.diffuse_colour = okmath.vec4_one()
	state.default_material.diffuse_map.use = texture_use.TEXTURE_USE_MAP_DIFFUSE
	state.default_material.diffuse_map.texture = texture_system_get_default_texture()

	if !renderer_create_material(&state.default_material) {
		log_fatal("Failed to acquire renderer resources for default texture.")
		return false
	}

	return true
}

material_config_load_from_file :: proc(path: string, out_config: ^material_config) -> bool {
	if out_config == nil {
		return false
	}

	f, ok := pl.filesystem_open(path, os.O_RDONLY)
	if !ok {
		log_error(
			"load_configuration_file - unable to open material file for reading: '%s'.",
			path,
		)
		return false
	}
	defer pl.filesystem_close(f)

	// Read each line of the file.
	line_buf: [512]u8
	line_length: u64 = 0
	line_number: u32 = 1
	for pl.filesystem_read_line(f, line_buf[:511], &line_length) {
		line := string(line_buf[:line_length])
		trimmed := string_trim(line)
		line_length = u64(string_length(trimmed))

		// Skip blank lines and comments.
		if line_length < 1 || trimmed[0] == '#' {
			line_number += 1
			continue
		}

		// Split into var/value.
		equal_index := string_index_of(trimmed, '=')
		if equal_index == -1 {
			log_warning(
				"Potential formatting issue found in file '%s': '=' token not found. Skipping line %v.",
				path,
				line_number,
			)
			line_number += 1
			continue
		}

		trimmed_var_name := string_trim(string_mid(trimmed, 0, equal_index))
		trimmed_value := string_trim(string_mid(trimmed, equal_index + 1, -1))

		// Process the variable.
		if strings_eqali(trimmed_var_name, "version") {
			// TODO: version
		} else if strings_eqali(trimmed_var_name, "name") {
			out_config.name = string_ncopy(trimmed_value, MATERIAL_NAME_MAX_LENGTH)
		} else if strings_eqali(trimmed_var_name, "diffuse_map_name") {
			out_config.diffuse_map_name = string_ncopy(trimmed_value, TEXTURE_NAME_MAX_LENGTH)
		} else if strings_eqali(trimmed_var_name, "diffuse_colour") {
			if !string_to_vec4(trimmed_value, &out_config.diffuse_colour) {
				log_warning(
					"Error parsing diffuse_colour in file '%s'. Using default of white instead.",
					path,
				)
				out_config.diffuse_colour = okmath.vec4_one()
			}
		}

		// TODO: more fields.
		line_number += 1
	}

	return true
}

material_system_acquire :: proc(name: string) -> ^material {
	config: material_config = {}
	filepath := fmt.aprintf("bin/assets/materials/%s.%s", name, "kmt")
	if !material_config_load_from_file(filepath, &config) {
		log_error("Failed to load material file")
		return nil
	}

	return material_system_acquire_from_config(config)
}

