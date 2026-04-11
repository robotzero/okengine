package systems

import c "../containers"
import k "../kstring"
import l "../logger"
import "../okmath"
import ren "../renderer"
import r "../resources"

DEFAULT_MATERIAL_NAME :: "default"

material_config :: r.material_config

material_system_config :: struct {
	max_material_count: u32,
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
	c.hashtable_create(
		size_of(material_reference),
		config.max_material_count,
		false,
		hashtable_var,
		nil,
		nil,
		allocator,
	)

	// Fill the hashtable with invalid references to use as a default.
	invalid_ref := material_reference {
		auto_release    = false,
		handle          = r.INVALID_ID, // Primary reason for needing default values.
		reference_count = 0,
	}
	state_ptr.registered_material_table = hashtable_var
	c.hashtable_fill(state_ptr.registered_material_table, invalid_ref)

	// Invalidate all textures in the array.
	for i in 0 ..< state_ptr.config.max_material_count {
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
		for i in 0 ..< state_ptr.config.max_material_count {
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
			for i in 0 ..< state_ptr.config.max_material_count {
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
			m^ = {}

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

	// Acquire instance resources from the named shader.
	shader_name := len(config.shader_name) > 0 ? config.shader_name : ren.BUILTIN_SHADER_NAME_MATERIAL
	m.shader_id = shader_system_get_id(shader_name)
	if m.shader_id == r.INVALID_ID {
		l.log_error("load_material: shader '%s' not found. Material '%s' will not load.", shader_name, m.name)
		return false
	}

	s := shader_system_get_by_id(m.shader_id)
	if !ren.renderer_shader_acquire_instance_resources(s, &m.internal_id) {
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

	// Release renderer resources via shader system.
	if m.shader_id != r.INVALID_ID && m.internal_id != r.INVALID_ID {
		s := shader_system_get_by_id(m.shader_id)
		if s != nil {
			ren.renderer_shader_release_instance_resources(s, m.internal_id)
		}
	}

	m.shader_id = r.INVALID_ID
	m.id = r.INVALID_ID
	m.generation = r.INVALID_ID
	m.internal_id = r.INVALID_ID
}

create_default_material :: proc(state: ^material_system_state) -> bool {
	state.default_material.id = r.INVALID_ID
	state.default_material.generation = r.INVALID_ID
	state.default_material.shader_id = r.INVALID_ID
	state.default_material.internal_id = r.INVALID_ID
	state.default_material.name = k.string_ncopy(DEFAULT_MATERIAL_NAME, r.MATERIAL_NAME_MAX_LENGTH)
	state.default_material.diffuse_colour = okmath.vec4_one()
	state.default_material.diffuse_map.use = r.texture_use.TEXTURE_USE_MAP_DIFFUSE
	state.default_material.diffuse_map.texture = texture_system_get_default_texture()

	// Default material uses the builtin material shader.
	state.default_material.shader_id = shader_system_get_id(ren.BUILTIN_SHADER_NAME_MATERIAL)
	if state.default_material.shader_id == r.INVALID_ID {
		l.log_fatal("create_default_material: builtin material shader not found.")
		return false
	}
	s := shader_system_get_by_id(state.default_material.shader_id)
	if !ren.renderer_shader_acquire_instance_resources(s, &state.default_material.internal_id) {
		l.log_fatal("Failed to acquire renderer resources for default material.")
		return false
	}

	return true
}

// ── Shader application helpers (called from renderer_draw_frame callbacks) ────

material_system_apply_global :: proc(shader_id: u32, proj, view: ^okmath.mat4) -> bool {
	s := shader_system_get_by_id(shader_id)
	if s == nil {
		return false
	}

	// Set projection and view uniforms by name.
	proj_idx := shader_system_uniform_index(s, "projection")
	view_idx := shader_system_uniform_index(s, "view")
	if proj_idx == r.INVALID_ID_U16 || view_idx == r.INVALID_ID_U16 {
		l.log_error("material_system_apply_global: projection/view uniform not found.")
		return false
	}

	shader_system_bind_globals()
	shader_system_uniform_set_by_index(proj_idx, proj)
	shader_system_uniform_set_by_index(view_idx, view)
	return shader_system_apply_global()
}

material_system_apply_instance :: proc(m: ^r.material) -> bool {
	s := shader_system_get_by_id(m.shader_id)
	if s == nil {
		return false
	}

	shader_system_bind_instance(m.internal_id)

	// Diffuse colour
	colour_idx := shader_system_uniform_index(s, "diffuse_colour")
	if colour_idx != r.INVALID_ID_U16 {
		shader_system_uniform_set_by_index(colour_idx, &m.diffuse_colour)
	}

	// Diffuse texture sampler
	tex_idx := shader_system_uniform_index(s, "diffuse_texture")
	if tex_idx != r.INVALID_ID_U16 {
		t := m.diffuse_map.texture
		if t == nil {
			t = texture_system_get_default_texture()
		}
		shader_system_uniform_set_by_index(tex_idx, &t)
	}

	return shader_system_apply_instance()
}

material_system_apply_local :: proc(m: ^r.material, model: ^okmath.mat4) -> bool {
	s := shader_system_get_by_id(m.shader_id)
	if s == nil {
		return false
	}
	model_idx := shader_system_uniform_index(s, "model")
	if model_idx == r.INVALID_ID_U16 {
		return false
	}
	return shader_system_uniform_set_by_index(model_idx, model)
}

material_system_get_default :: proc() -> ^r.material {
	if state_ptr != nil {
		return &state_ptr.default_material
	}
	l.log_fatal("material_system_get_default called before system was initialized. Returning nil.")
	return nil
}

material_system_acquire :: proc(name: string) -> ^r.material {
	// Load material configuration from resource system.
	material_resource: r.resource
	if !resource_system_load(name, .MATERIAL, &material_resource) {
		l.log_error("Failed to load material resource, returning nil.")
		return nil
	}

	m: ^r.material = nil
	if config, ok := material_resource.data.(r.material_config); ok {
		m = material_system_acquire_from_config(config)
	}

	// Clean up the resource.
	resource_system_unload(&material_resource)

	if m == nil {
		l.log_error("Failed to load material resource, returning nil.")
	}

	return m
}
