package core

import "../okmath"

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

		destroy_material(&s.default_material)
		// free(state_ptr.registered_texture_table)

		state_ptr = nil
	}
}
material_system_acquire_from_config :: proc(config: material_config) -> ^material {
	// Return default material
	if strings.equal_fold(name, DEFAULT_MATERIAL_NAME) {
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
				log_error("Failed to load texture '%s'.", name)
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
		name,
	)
	return nil
}

material_system_release :: proc(name: string) {
	// Ignore release requests for the default texture.
	if strings.equal_fold(name, DEFAULT_MATERIAL_NAME) {
		return
	}
	ref: material_reference
	if state_ptr != nil &&
	   hashtable_get(state_ptr.registered_material_table, name, texture_reference, &ref) {
		if ref.reference_count == 0 {
			log_warning("Tried to release non-existent texture: '%s'", name)
			return
		}
		ref.reference_count -= 1
		if ref.reference_count == 0 && ref.auto_release {
			m := &state_ptr.registered_materialss[ref.handle]

			// Release texture.
			destroy_texture(m)

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

