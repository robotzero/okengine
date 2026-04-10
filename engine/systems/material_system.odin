package systems

import c "../containers"
import k "../kstring"
import l "../logger"
import "../okmath"
import f "../platform/linux/filesystem"
import ren "../renderer"
import r "../resources"
import "core:fmt"
import "core:mem"

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
	default_material:          r.material,
	registered_materials:      []r.material,
	registered_material_table: ^c.hashtable(material_reference),
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
		l.log_fatal("texture_system_initialize - config.max_texture_count must be > 0.")
		return false
	}
	if state == nil {
		return true
	}

	state_ptr = state
	state_ptr.config = config

	//@MEMORY use containers so that we can tag the memory
	state_ptr.registered_materials = make([]r.material, config.max_material_count, allocator)

	//@MEMORY use containers to that we can tag memory
	hashtable_var := new(c.hashtable(material_reference), allocator)
	hashtable_memory := make([]material_reference, config.max_material_count, allocator)

	// Create a hashtable for texture lookups.
	c.hashtable_create(
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
	invalid_ref.handle = r.INVALID_ID // Primary reason for needing default values.
	invalid_ref.reference_count = 0
	state_ptr.registered_material_table = hashtable_var
	c.hashtable_fill(state_ptr.registered_material_table, invalid_ref)

	// Invalidate all textures in the array.
	for i: u32 = 0; i < state_ptr.config.max_material_count; i += 1 {
		state_ptr.registered_materials[i].id = r.INVALID_ID
		state_ptr.registered_materials[i].generation = r.INVALID_ID
		state_ptr.registered_materials[i].internal_id = r.INVALID_ID
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
			if s.id != r.INVALID_ID {
				destroy_material(s)
			}
		}

		destroy_material(&state_ptr.default_material)
		// free(state_ptr.registered_texture_table)

		state_ptr = nil
	}
}
material_system_acquire_from_config :: proc(config: material_config) -> ^r.material {
	// Return default material
	if k.strings_eqali(config.name, DEFAULT_MATERIAL_NAME) {
		return &state_ptr.default_material
	}

	ref: material_reference
	if state_ptr != nil && c.hashtable_get(state_ptr.registered_material_table, config.name, &ref) {
		// This can only be changed the first time a material is loaded.
		if ref.reference_count == 0 {
			ref.auto_release = config.auto_release
		}
		ref.reference_count += 1
		if ref.handle == r.INVALID_ID {
			// This means no material exists here. Find a free index first.
			m: ^r.material = nil
			for i: u32 = 0; i < state_ptr.config.max_material_count; i += 1 {
				if state_ptr.registered_materials[i].id == r.INVALID_ID {
					// A free slot has been found. Use its index as the handle.
					ref.handle = i
					m = &state_ptr.registered_materials[i]
					break
				}
			}

			// Make sure an empty slot was actually found.
			if m == nil || ref.handle == r.INVALID_ID {
				l.log_fatal(
					"material_system_acquire - Material system cannot hold anymore materials. Adjust configuration to allow more.",
				)
				return nil
			}

			// Create new material.
			if !load_material(config, m) {
				l.log_error("Failed to load material '%s'.", config.name)
				return nil
			}

			if m.generation == r.INVALID_ID {
				m.generation = 0
			} else {
				m.generation += 1
			}

			// Also use the handle as the material id.
			m.id = ref.handle
			l.log_debug(
				"Material '%s' does not yet exist. Created, and ref_count is now %i.",
				config.name,
				ref.reference_count,
			)
		} else {
			l.log_debug(
				"Material '%s' already exists, ref_count increased to %i.",
				config.name,
				ref.reference_count,
			)
		}

		// Update the entry.
		c.hashtable_set(state_ptr.registered_material_table, config.name, ref)
		return &state_ptr.registered_materials[ref.handle]
	}

	// NOTE: This would only happen in the event something went wrong with the state.
	l.log_error(
		"material_system_acquire failed to acquire material '%s'. Null pointer will be returned.",
		config.name,
	)
	return nil
}

material_system_release :: proc(name: string) {
	// Ignore release requests for the default texture.
	if k.strings_eqali(name, DEFAULT_MATERIAL_NAME) {
		return
	}
	ref: material_reference
	if state_ptr != nil && c.hashtable_get(state_ptr.registered_material_table, name, &ref) {
		if ref.reference_count == 0 {
			l.log_warning("Tried to release non-existent material: '%s'", name)
			return
		}
		ref.reference_count -= 1
		if ref.reference_count == 0 && ref.auto_release {
			m := &state_ptr.registered_materials[ref.handle]

			// Release material.
			destroy_material(m)

			// Reset the array entry, ensure invalid ids are set.
			mem.set(m, 0, size_of(r.material))

			// Reset the reference.
			ref.handle = r.INVALID_ID
			ref.auto_release = false
			l.log_debug(
				"Released material '%s'. Material unloaded because reference count=0 and auto_release=true.",
				name,
			)
		} else {
			l.log_debug(
				"Released material '%s', now has a reference count of '%i' (auto_release=%s).",
				name,
				ref.reference_count,
				ref.auto_release,
			)
		}

		// Update the entry.
		c.hashtable_set(state_ptr.registered_material_table, name, ref)
	} else {
		l.log_error("material_system_release failed to release material '%s'.", name)
	}
}

load_material :: proc(config: material_config, m: ^r.material) -> bool {
	m.name = k.string_ncopy(config.name, r.MATERIAL_NAME_MAX_LENGTH)
	m.diffuse_colour = config.diffuse_colour

	if len(config.diffuse_map_name) > 0 {
		m.diffuse_map.use = r.texture_use.TEXTURE_USE_MAP_DIFFUSE
		m.diffuse_map.texture = texture_system_acquire(config.diffuse_map_name, true)
		if m.diffuse_map.texture == nil {
			l.log_warning("Unable to load texture")
			m.diffuse_map.texture = texture_system_get_default_texture()
		}
	} else {
		m.diffuse_map.use = r.texture_use.TEXTURE_USE_UNKNOWN
		m.diffuse_map.texture = nil
	}

	// Send it off to the renderer to acquire resources
	if !ren.renderer_create_material(m) {
		l.log_error("Failed to acquire renderer resources for material '%s'", m.name)
		return false
	}

	return true
}

destroy_material :: proc(m: ^r.material) {
	l.log_debug("Destroying material '%s'", m.name)

	// Release texture references
	if m.diffuse_map.texture != nil {
		texture_system_release(m.diffuse_map.texture.name)
	}

	// Release renderer resources
	ren.renderer_destroy_material(m)

	m.id = r.INVALID_ID
	m.generation = r.INVALID_ID
	m.internal_id = r.INVALID_ID
}

create_default_material :: proc(state: ^material_system_state) -> bool {
	state.default_material.id = r.INVALID_ID
	state.default_material.generation = r.INVALID_ID
	state.default_material.name = k.string_ncopy(DEFAULT_MATERIAL_NAME, r.MATERIAL_NAME_MAX_LENGTH)
	state.default_material.diffuse_colour = okmath.vec4_one()
	state.default_material.diffuse_map.use = r.texture_use.TEXTURE_USE_MAP_DIFFUSE
	state.default_material.diffuse_map.texture = texture_system_get_default_texture()

	if !ren.renderer_create_material(&state.default_material) {
		l.log_fatal("Failed to acquire renderer resources for default texture.")
		return false
	}

	return true
}

material_config_load_from_file :: proc(path: string, out_config: ^material_config) -> bool {
	if out_config == nil {
		return false
	}

	fh, ok := f.filesystem_open(path)
	if !ok {
		l.log_error(
			"load_configuration_file - unable to open material file for reading: '%s'.",
			path,
		)
		return false
	}
	defer f.filesystem_close(fh)

	// Read each line of the file.
	line_buf: [512]u8
	line_length: u64 = 0
	line_number: u32 = 1
	for f.filesystem_read_line(fh, line_buf[:511], &line_length) {
		line := string(line_buf[:line_length])
		trimmed := k.string_trim(line)
		line_length = u64(k.string_length(trimmed))

		// Skip blank lines and comments.
		if line_length < 1 || trimmed[0] == '#' {
			line_number += 1
			continue
		}

		// Split into var/value.
		equal_index := k.string_index_of(trimmed, '=')
		if equal_index == -1 {
			l.log_warning(
				"Potential formatting issue found in file '%s': '=' token not found. Skipping line %v.",
				path,
				line_number,
			)
			line_number += 1
			continue
		}

		trimmed_var_name := k.string_trim(k.string_mid(trimmed, 0, equal_index))
		trimmed_value := k.string_trim(k.string_mid(trimmed, equal_index + 1, -1))

		// Process the variable.
		if k.strings_eqali(trimmed_var_name, "version") {
			// TODO: version
		} else if k.strings_eqali(trimmed_var_name, "name") {
			out_config.name = k.string_ncopy(trimmed_value, r.MATERIAL_NAME_MAX_LENGTH)
		} else if k.strings_eqali(trimmed_var_name, "diffuse_map_name") {
			out_config.diffuse_map_name = k.string_ncopy(trimmed_value, r.TEXTURE_NAME_MAX_LENGTH)
		} else if k.strings_eqali(trimmed_var_name, "diffuse_colour") {
			if !k.string_to_vec4(trimmed_value, &out_config.diffuse_colour) {
				l.log_warning(
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

material_system_acquire :: proc(name: string) -> ^r.material {
	config: material_config = {}
	filepath := fmt.aprintf("assets/materials/%s.%s", name, "okmt")
	defer delete(filepath)
	if !material_config_load_from_file(filepath, &config) {
		l.log_error("Failed to load material file")
		return nil
	}

	return material_system_acquire_from_config(config)
}
