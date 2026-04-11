package systems

import k "../kstring"
import l "../logger"
import ren "../renderer"
import r "../resources"
import "core:strings"

BUILTIN_SHADER_NAME_MATERIAL :: ren.BUILTIN_SHADER_NAME_MATERIAL
BUILTIN_SHADER_NAME_UI :: ren.BUILTIN_SHADER_NAME_UI

shader_system_config :: struct {
	max_shader_count:       u32,
	max_uniform_count:      u16,
	max_global_textures:    u8,
	max_instance_textures:  u8,
}

shader_system_state :: struct {
	config:            shader_system_config,
	// name -> index in shaders array
	lookup:            map[string]u32,
	current_shader_id: u32,
	shaders:           []r.shader,
}

@(private = "file")
shader_state_ptr: ^shader_system_state

shader_system_initialize :: proc(state: ^shader_system_state, config: shader_system_config) -> bool {
	if config.max_shader_count == 0 {
		l.log_error("shader_system_initialize: config.max_shader_count must be > 0.")
		return false
	}
	if state == nil {
		return true
	}

	shader_state_ptr = state
	shader_state_ptr.config = config
	shader_state_ptr.current_shader_id = r.INVALID_ID
	shader_state_ptr.lookup = make(map[string]u32)
	shader_state_ptr.shaders = make([]r.shader, config.max_shader_count)

	// Invalidate all shader ids.
	for i in 0 ..< config.max_shader_count {
		shader_state_ptr.shaders[i].id = r.INVALID_ID
	}

	return true
}

shader_system_shutdown :: proc() {
	if shader_state_ptr != nil {
		// Clear the lookup map first (its keys are the same pointers as s.name,
		// which internal_shader_destroy will free — so we must not let the map
		// try to use them after that).
		clear(&shader_state_ptr.lookup)
		delete(shader_state_ptr.lookup)

		for i in 0 ..< shader_state_ptr.config.max_shader_count {
			s := &shader_state_ptr.shaders[i]
			if s.id != r.INVALID_ID {
				internal_shader_destroy(s)
			}
		}
		delete(shader_state_ptr.shaders)
		shader_state_ptr = nil
	}
}

shader_system_create :: proc(config: ^r.shader_config) -> bool {
	id := new_shader_id()
	if id == r.INVALID_ID {
		l.log_error("shader_system_create: no free slot available for shader '%s'.", config.name)
		return false
	}

	out_shader := &shader_state_ptr.shaders[id]
	out_shader^ = {}
	out_shader.id = id
	out_shader.state = .NOT_CREATED
	out_shader.name = strings.clone(config.name)
	out_shader.use_instances = config.use_instances
	out_shader.use_locals = config.use_local
	out_shader.push_constant_range_count = 0
	out_shader.bound_instance_id = r.INVALID_ID
	out_shader.attribute_stride = 0
	out_shader.push_constant_stride = 128 // Vulkan spec guarantees at least 128 bytes
	out_shader.push_constant_size = 0

	out_shader.global_textures = make([dynamic]^r.texture)
	out_shader.uniforms = make([dynamic]r.shader_uniform)
	out_shader.attributes = make([dynamic]r.shader_attribute)
	out_shader.uniform_lookup = make(map[string]u16)

	out_shader.global_ubo_size = 0
	out_shader.ubo_size = 0

	// Resolve renderpass id
	renderpass_id: u8 = r.INVALID_ID_U8
	if !renderer_renderpass_id(config.renderpass_name, &renderpass_id) {
		l.log_error("shader_system_create: unable to find renderpass '%s'.", config.renderpass_name)
		return false
	}

	// Create the shader in the backend.
	if !ren.renderer_shader_create(out_shader, renderpass_id, config.stage_count, config.stage_filenames[:], config.stages[:]) {
		l.log_error("shader_system_create: error creating shader '%s'.", config.name)
		return false
	}

	out_shader.state = .UNINITIALIZED

	// Process attributes
	for i in 0 ..< int(config.attribute_count) {
		add_attribute(out_shader, &config.attributes[i])
	}

	// Process uniforms and samplers
	for i in 0 ..< int(config.uniform_count) {
		if config.uniforms[i].type == .SAMPLER {
			add_sampler(out_shader, &config.uniforms[i])
		} else {
			add_uniform(out_shader, &config.uniforms[i])
		}
	}

	// Initialize the shader (creates pipeline, UBO, descriptor sets, etc.)
	if !ren.renderer_shader_initialize(out_shader) {
		l.log_error("shader_system_create: initialization failed for shader '%s'.", config.name)
		return false
	}

	// Store in lookup (name is already cloned above, reuse same string as map key).
	shader_state_ptr.lookup[out_shader.name] = out_shader.id

	return true
}

shader_system_get_id :: proc(shader_name: string) -> u32 {
	if id, ok := shader_state_ptr.lookup[shader_name]; ok {
		return id
	}
	return r.INVALID_ID
}

shader_system_get_by_id :: proc(shader_id: u32) -> ^r.shader {
	if shader_id >= shader_state_ptr.config.max_shader_count {
		return nil
	}
	s := &shader_state_ptr.shaders[shader_id]
	if s.id == r.INVALID_ID {
		return nil
	}
	return s
}

shader_system_get :: proc(shader_name: string) -> ^r.shader {
	id := shader_system_get_id(shader_name)
	if id != r.INVALID_ID {
		return shader_system_get_by_id(id)
	}
	return nil
}

shader_system_destroy :: proc(shader_name: string) {
	id := shader_system_get_id(shader_name)
	if id == r.INVALID_ID {
		return
	}
	s := &shader_state_ptr.shaders[id]
	internal_shader_destroy(s)
	delete_key(&shader_state_ptr.lookup, shader_name)
}

shader_system_use :: proc(shader_name: string) -> bool {
	id := shader_system_get_id(shader_name)
	if id == r.INVALID_ID {
		l.log_error("shader_system_use: shader '%s' not found.", shader_name)
		return false
	}
	return shader_system_use_by_id(id)
}

shader_system_use_by_id :: proc(shader_id: u32) -> bool {
	s := shader_system_get_by_id(shader_id)
	if s == nil {
		return false
	}
	shader_state_ptr.current_shader_id = shader_id
	return ren.renderer_shader_use(s)
}

shader_system_bind_globals :: proc() -> bool {
	s := shader_system_get_by_id(shader_state_ptr.current_shader_id)
	if s == nil {
		return false
	}
	s.bound_ubo_offset = u64(s.global_ubo_offset)
	return ren.renderer_shader_bind_globals(s)
}

shader_system_bind_instance :: proc(instance_id: u32) -> bool {
	s := shader_system_get_by_id(shader_state_ptr.current_shader_id)
	if s == nil {
		return false
	}
	s.bound_instance_id = instance_id
	return ren.renderer_shader_bind_instance(s, instance_id)
}

shader_system_apply_global :: proc() -> bool {
	s := shader_system_get_by_id(shader_state_ptr.current_shader_id)
	if s == nil {
		return false
	}
	return ren.renderer_shader_apply_globals(s)
}

shader_system_apply_instance :: proc() -> bool {
	s := shader_system_get_by_id(shader_state_ptr.current_shader_id)
	if s == nil {
		return false
	}
	return ren.renderer_shader_apply_instance(s)
}

shader_system_uniform_index :: proc(s: ^r.shader, uniform_name: string) -> u16 {
	if idx, ok := s.uniform_lookup[uniform_name]; ok {
		return idx
	}
	return r.INVALID_ID_U16
}

shader_system_uniform_set :: proc(uniform_name: string, value: rawptr) -> bool {
	s := shader_system_get_by_id(shader_state_ptr.current_shader_id)
	if s == nil {
		return false
	}
	idx := shader_system_uniform_index(s, uniform_name)
	if idx == r.INVALID_ID_U16 {
		l.log_error("shader_system_uniform_set: uniform '%s' not found.", uniform_name)
		return false
	}
	return shader_system_uniform_set_by_index(idx, value)
}

shader_system_uniform_set_by_index :: proc(index: u16, value: rawptr) -> bool {
	s := shader_system_get_by_id(shader_state_ptr.current_shader_id)
	if s == nil || int(index) >= len(s.uniforms) {
		return false
	}
	u := &s.uniforms[index]
	return ren.renderer_set_uniform(s, u, value)
}

// ── Internal helpers ──────────────────────────────────────────────────────────

@(private = "file")
new_shader_id :: proc() -> u32 {
	for i in u32(0) ..< shader_state_ptr.config.max_shader_count {
		if shader_state_ptr.shaders[i].id == r.INVALID_ID {
			return i
		}
	}
	return r.INVALID_ID
}

@(private = "file")
internal_shader_destroy :: proc(s: ^r.shader) {
	ren.renderer_shader_destroy(s)
	s.state = .NOT_CREATED

	// Free cloned strings stored as uniform_lookup map keys.
	for key in s.uniform_lookup {
		delete(key)
	}
	delete(s.uniform_lookup)

	// Free attribute name strings.
	for a in s.attributes {
		delete(a.name)
	}
	delete(s.attributes)

	delete(s.uniforms)
	delete(s.global_textures)

	// Free the cloned shader name (same pointer is used as the lookup key in shader_state_ptr.lookup,
	// so we must not double-free; the map key is removed by the caller before this is invoked
	// — or we just free here and the map retains a now-invalid key, which is fine since the map
	// entry is deleted by shader_system_destroy / shader_system_shutdown before freeing).
	delete(s.name)
	s.name = ""
}

@(private = "file")
add_attribute :: proc(s: ^r.shader, config: ^r.shader_attribute_config) {
	attr := r.shader_attribute {
		name = strings.clone(config.name),
		size = u32(config.size),
		type = config.type,
	}
	s.attribute_stride += u32(config.size)
	append(&s.attributes, attr)
}

@(private = "file")
add_uniform :: proc(s: ^r.shader, config: ^r.shader_uniform_config) {
	if !uniform_name_valid(s, config.name) {
		return
	}

	u := r.shader_uniform {
		index     = u16(len(s.uniforms)),
		scope     = config.scope,
		type      = config.type,
		size      = u16(config.size),
		set_index = config.scope == .GLOBAL ? 0 : 1,
	}

	if config.scope == .LOCAL {
		// Push constant — offset into the push constant block
		u.offset = s.push_constant_size
		s.push_constant_size += u64(config.size)
		// Register a push constant range
		if s.push_constant_range_count < 32 {
			s.push_constant_ranges[s.push_constant_range_count] = r.shader_push_constant_range {
				offset = u.offset,
				size   = u64(config.size),
			}
			s.push_constant_range_count += 1
		}
	} else if config.scope == .GLOBAL {
		u.offset = s.global_ubo_size
		s.global_ubo_size += u64(config.size)
	} else {
		u.offset = s.ubo_size
		s.ubo_size += u64(config.size)
	}

	u.location = u16(len(s.uniforms))
	s.uniform_lookup[strings.clone(config.name)] = u.location
	append(&s.uniforms, u)
}

@(private = "file")
add_sampler :: proc(s: ^r.shader, config: ^r.shader_uniform_config) {
	if !uniform_name_valid(s, config.name) {
		return
	}

	// Determine texture slot location within its scope
	location: u16
	if config.scope == .GLOBAL {
		location = u16(len(s.global_textures))
		append(&s.global_textures, (^r.texture)(nil))
	} else {
		location = u16(s.instance_texture_count)
		s.instance_texture_count += 1
	}

	u := r.shader_uniform {
		index     = u16(len(s.uniforms)),
		scope     = config.scope,
		type      = .SAMPLER,
		size      = 0,
		location  = location,
		set_index = config.scope == .GLOBAL ? 0 : 1,
		offset    = 0,
	}

	u.location = u16(len(s.uniforms))
	s.uniform_lookup[strings.clone(config.name)] = u.location
	append(&s.uniforms, u)
}

@(private = "file")
uniform_name_valid :: proc(s: ^r.shader, name: string) -> bool {
	if _, ok := s.uniform_lookup[name]; ok {
		l.log_error("shader uniform '%s' already exists — duplicates not allowed.", name)
		return false
	}
	return true
}

// ── Renderer forwarding helpers (called from material_system) ─────────────────

renderer_renderpass_id :: proc(name: string, out_id: ^u8) -> bool {
	if k.strings_eqali(name, "Renderpass.Builtin.World") {
		out_id^ = u8(ren.builtin_renderpass.WORLD)
		return true
	} else if k.strings_eqali(name, "Renderpass.Builtin.UI") {
		out_id^ = u8(ren.builtin_renderpass.UI)
		return true
	}
	l.log_error("renderer_renderpass_id: no renderpass named '%s'.", name)
	out_id^ = r.INVALID_ID_U8
	return false
}
