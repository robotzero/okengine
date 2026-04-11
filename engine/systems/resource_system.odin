package systems

import k "../kstring"
import l "../logger"
import "../okmath"
import f "../platform/linux/filesystem"
import r "../resources"
import "core:fmt"
import "core:strings"
import si "vendor:stb/image"

resource_loader_load_proc :: #type proc(
	loader: ^resource_loader,
	name: string,
	out_resource: ^r.resource,
) -> bool
resource_loader_unload_proc :: #type proc(
	loader: ^resource_loader,
	resource: ^r.resource,
)

resource_loader :: struct {
	id:          u32,
	type:        r.resource_type,
	custom_type: string,
	type_path:   string,
	load:        resource_loader_load_proc,
	unload:      resource_loader_unload_proc,
}

resource_system_config :: struct {
	max_loader_count: u32,
	asset_base_path:  string,
}

resource_system_state :: struct {
	config:             resource_system_config,
	registered_loaders: []resource_loader,
}

@(private = "file")
res_state_ptr: ^resource_system_state

resource_system_initialize :: proc(
	state: ^resource_system_state,
	config: resource_system_config,
) -> bool {
	if config.max_loader_count == 0 {
		l.log_fatal("resource_system_initialize failed because config.max_loader_count==0.")
		return false
	}
	if state == nil {
		return true
	}

	res_state_ptr = state
	res_state_ptr.config = config
	res_state_ptr.registered_loaders = make([]resource_loader, config.max_loader_count)

	// Invalidate all loaders.
	for i in 0 ..< config.max_loader_count {
		res_state_ptr.registered_loaders[i].id = r.INVALID_ID
	}

	// Auto-register known loader types.
	resource_system_register_loader(text_loader_create())
	resource_system_register_loader(binary_loader_create())
	resource_system_register_loader(image_loader_create())
	resource_system_register_loader(material_loader_create())

	l.log_info("Resource system initialized with base path '%s'.", config.asset_base_path)

	return true
}

resource_system_shutdown :: proc() {
	if res_state_ptr != nil {
		delete(res_state_ptr.registered_loaders)
		res_state_ptr = nil
	}
}

resource_system_register_loader :: proc(loader: resource_loader) -> bool {
	if res_state_ptr == nil {
		return false
	}
	count := res_state_ptr.config.max_loader_count

	// Ensure no loaders for the given type already exist.
	for i in 0 ..< count {
		lo := &res_state_ptr.registered_loaders[i]
		if lo.id != r.INVALID_ID {
			if lo.type == loader.type {
				l.log_error(
					"resource_system_register_loader - Loader of type %v already exists and will not be registered.",
					loader.type,
				)
				return false
			} else if len(loader.custom_type) > 0 &&
			   k.strings_eqali(lo.custom_type, loader.custom_type) {
				l.log_error(
					"resource_system_register_loader - Loader of custom type %s already exists and will not be registered.",
					loader.custom_type,
				)
				return false
			}
		}
	}
	for i in 0 ..< count {
		if res_state_ptr.registered_loaders[i].id == r.INVALID_ID {
			res_state_ptr.registered_loaders[i] = loader
			res_state_ptr.registered_loaders[i].id = i
			l.log_debug("Loader registered.")
			return true
		}
	}

	return false
}

resource_system_load :: proc(
	name: string,
	type: r.resource_type,
	out_resource: ^r.resource,
) -> bool {
	if res_state_ptr != nil && type != .CUSTOM {
		count := res_state_ptr.config.max_loader_count
		for i in 0 ..< count {
			lo := &res_state_ptr.registered_loaders[i]
			if lo.id != r.INVALID_ID && lo.type == type {
				out_resource.loader_id = lo.id
				return lo.load(lo, name, out_resource)
			}
		}
	}

	out_resource.loader_id = r.INVALID_ID
	l.log_error("resource_system_load - No loader for type %v was found.", type)
	return false
}

resource_system_load_custom :: proc(
	name: string,
	custom_type: string,
	out_resource: ^r.resource,
) -> bool {
	if res_state_ptr != nil && len(custom_type) > 0 {
		count := res_state_ptr.config.max_loader_count
		for i in 0 ..< count {
			lo := &res_state_ptr.registered_loaders[i]
			if lo.id != r.INVALID_ID &&
			   lo.type == .CUSTOM &&
			   k.strings_eqali(lo.custom_type, custom_type) {
				out_resource.loader_id = lo.id
				return lo.load(lo, name, out_resource)
			}
		}
	}

	out_resource.loader_id = r.INVALID_ID
	l.log_error(
		"resource_system_load_custom - No loader for type %s was found.",
		custom_type,
	)
	return false
}

resource_system_unload :: proc(resource: ^r.resource) {
	if res_state_ptr != nil && resource != nil {
		if resource.loader_id != r.INVALID_ID {
			lo := &res_state_ptr.registered_loaders[resource.loader_id]
			if lo.id != r.INVALID_ID && lo.unload != nil {
				lo.unload(lo, resource)
			}
		}
	}
}

resource_system_base_path :: proc() -> string {
	if res_state_ptr != nil {
		return res_state_ptr.config.asset_base_path
	}
	l.log_error(
		"resource_system_base_path called before initialization, returning empty string.",
	)
	return ""
}

// ────────────────────────────────────────────────
// Built-in loader implementations
// ────────────────────────────────────────────────

// --- Text loader ---

@(private = "file")
text_loader_load :: proc(
	self: ^resource_loader,
	name: string,
	out_resource: ^r.resource,
) -> bool {
	full_path := fmt.aprintf(
		"%s/%s/%s",
		resource_system_base_path(),
		self.type_path,
		name,
	)
	defer delete(full_path)

	fh, ok := f.filesystem_open(full_path)
	if !ok {
		l.log_error("text_loader_load - unable to open file for reading: '%s'.", full_path)
		return false
	}
	defer f.filesystem_close(fh)

	text, read_ok := f.filesystem_read_all_text(fh)
	if !read_ok {
		l.log_error("Unable to read text file: %s.", full_path)
		return false
	}

	out_resource.full_path = strings.clone(full_path)
	out_resource.data = r.text_resource_data{text = text}
	out_resource.name = name
	return true
}

@(private = "file")
text_loader_unload :: proc(self: ^resource_loader, resource: ^r.resource) {
	if resource != nil {
		if td, ok := resource.data.(r.text_resource_data); ok {
			delete(td.text)
		}
		if len(resource.full_path) > 0 {
			delete(resource.full_path)
		}
		resource.data = nil
		resource.loader_id = r.INVALID_ID
	}
}

@(private = "file")
text_loader_create :: proc() -> resource_loader {
	return resource_loader {
		type      = .TEXT,
		load      = text_loader_load,
		unload    = text_loader_unload,
		type_path = "",
	}
}

// --- Binary loader ---

@(private = "file")
binary_loader_load :: proc(
	self: ^resource_loader,
	name: string,
	out_resource: ^r.resource,
) -> bool {
	full_path := fmt.aprintf(
		"%s/%s/%s",
		resource_system_base_path(),
		self.type_path,
		name,
	)
	defer delete(full_path)

	fh, ok := f.filesystem_open(full_path)
	if !ok {
		l.log_error(
			"binary_loader_load - unable to open file for reading: '%s'.",
			full_path,
		)
		return false
	}
	defer f.filesystem_close(fh)

	data := f.file_system_read_all_bytes(fh)
	if data == nil {
		l.log_error("Unable to read binary file: %s.", full_path)
		return false
	}

	out_resource.full_path = strings.clone(full_path)
	out_resource.data = r.binary_resource_data{bytes = data}
	out_resource.name = name
	return true
}

@(private = "file")
binary_loader_unload :: proc(self: ^resource_loader, resource: ^r.resource) {
	if resource != nil {
		if bd, ok := resource.data.(r.binary_resource_data); ok {
			delete(bd.bytes)
		}
		if len(resource.full_path) > 0 {
			delete(resource.full_path)
		}
		resource.data = nil
		resource.loader_id = r.INVALID_ID
	}
}

@(private = "file")
binary_loader_create :: proc() -> resource_loader {
	return resource_loader {
		type      = .BINARY,
		load      = binary_loader_load,
		unload    = binary_loader_unload,
		type_path = "",
	}
}

// --- Image loader ---

@(private = "file")
image_loader_load :: proc(
	self: ^resource_loader,
	name: string,
	out_resource: ^r.resource,
) -> bool {
	required_channel_count: i32 = 4
	si.set_flip_vertically_on_load(1)
	full_path := fmt.aprintf(
		"%s/%s/%s.png",
		resource_system_base_path(),
		self.type_path,
		name,
	)
	defer delete(full_path)

	si_path := strings.clone_to_cstring(full_path)
	defer delete(si_path)

	width_i32: i32
	height_i32: i32
	channel_count_i32: i32
	data := si.load(
		si_path,
		&width_i32,
		&height_i32,
		&channel_count_i32,
		required_channel_count,
	)

	fail_reason := si.failure_reason()
	if fail_reason != nil {
		l.log_error(
			"Image resource loader failed to load file '%s': %s",
			full_path,
			fail_reason,
		)
		if data != nil {
			si.image_free(data)
		}
		return false
	}

	if data == nil {
		l.log_error("Image resource loader failed to load file '%s'.", full_path)
		return false
	}

	resource_data := r.image_resource_data {
		pixels        = data,
		width         = u32(width_i32),
		height        = u32(height_i32),
		channel_count = u8(required_channel_count),
	}

	out_resource.full_path = strings.clone(full_path)
	out_resource.data = resource_data
	out_resource.name = name
	return true
}

@(private = "file")
image_loader_unload :: proc(self: ^resource_loader, resource: ^r.resource) {
	if resource != nil {
		if id, ok := resource.data.(r.image_resource_data); ok {
			if id.pixels != nil {
				si.image_free(id.pixels)
			}
		}
		if len(resource.full_path) > 0 {
			delete(resource.full_path)
		}
		resource.data = nil
		resource.loader_id = r.INVALID_ID
	}
}

@(private = "file")
image_loader_create :: proc() -> resource_loader {
	return resource_loader {
		type      = .IMAGE,
		load      = image_loader_load,
		unload    = image_loader_unload,
		type_path = "textures",
	}
}

// --- Material loader ---

@(private = "file")
material_loader_load :: proc(
	self: ^resource_loader,
	name: string,
	out_resource: ^r.resource,
) -> bool {
	full_path := fmt.aprintf(
		"%s/%s/%s.okmt",
		resource_system_base_path(),
		self.type_path,
		name,
	)
	defer delete(full_path)

	fh, ok := f.filesystem_open(full_path)
	if !ok {
		l.log_error(
			"material_loader_load - unable to open material file for reading: '%s'.",
			full_path,
		)
		return false
	}
	defer f.filesystem_close(fh)

	// Set defaults.
	config := r.material_config {
		auto_release   = true,
		diffuse_colour = okmath.vec4_one(),
		name           = k.string_ncopy(name, r.MATERIAL_NAME_MAX_LENGTH),
	}

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
				full_path,
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
			config.name = k.string_ncopy(trimmed_value, r.MATERIAL_NAME_MAX_LENGTH)
		} else if k.strings_eqali(trimmed_var_name, "diffuse_map_name") {
			config.diffuse_map_name = k.string_ncopy(
				trimmed_value,
				r.TEXTURE_NAME_MAX_LENGTH,
			)
		} else if k.strings_eqali(trimmed_var_name, "diffuse_colour") {
			if !k.string_to_vec4(trimmed_value, &config.diffuse_colour) {
				l.log_warning(
					"Error parsing diffuse_colour in file '%s'. Using default of white instead.",
					full_path,
				)
			}
		} else if k.strings_eqali(trimmed_var_name, "type") {
			if k.strings_eqali(trimmed_value, "ui") {
				config.type = r.material_type.MATERIAL_TYPE_UI
			} else {
				config.type = r.material_type.MATERIAL_TYPE_WORLD
			}
		}

		// TODO: more fields.
		line_number += 1
	}

	out_resource.full_path = strings.clone(full_path)
	out_resource.data = config
	out_resource.name = name
	return true
}

@(private = "file")
material_loader_unload :: proc(self: ^resource_loader, resource: ^r.resource) {
	if resource != nil {
		if len(resource.full_path) > 0 {
			delete(resource.full_path)
		}
		resource.data = nil
		resource.loader_id = r.INVALID_ID
	}
}

@(private = "file")
material_loader_create :: proc() -> resource_loader {
	return resource_loader {
		type      = .MATERIAL,
		load      = material_loader_load,
		unload    = material_loader_unload,
		type_path = "materials",
	}
}
