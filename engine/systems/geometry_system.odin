package systems

import k "../kstring"
import l "../logger"
import "../okmath"
import ren "../renderer"
import r "../resources"

DEFAULT_GEOMETRY_NAME :: "default"

geometry_system_config :: struct {
	max_geometry_count: u32,
}

geometry_reference :: struct {
	reference_count: u64,
	auto_release:    bool,
}

geometry_system_state :: struct {
	config:               geometry_system_config,
	default_geometry:     r.geometry,
	registered_geometries: []r.geometry,
	geometry_references:  []geometry_reference,
}

@(private = "file")
geo_state_ptr: ^geometry_system_state

geometry_system_initialize :: proc(
	state: ^geometry_system_state,
	config: geometry_system_config,
) -> bool {
	if config.max_geometry_count == 0 {
		l.log_fatal("geometry_system_initialize - config.max_geometry_count must be > 0.")
		return false
	}
	if state == nil {
		return true
	}

	geo_state_ptr = state
	geo_state_ptr.config = config

	geo_state_ptr.registered_geometries = make([]r.geometry, config.max_geometry_count)
	geo_state_ptr.geometry_references = make([]geometry_reference, config.max_geometry_count)

	// Invalidate all geometries in the array.
	for i in 0 ..< config.max_geometry_count {
		geo_state_ptr.registered_geometries[i].id = r.INVALID_ID
		geo_state_ptr.registered_geometries[i].internal_id = r.INVALID_ID
		geo_state_ptr.registered_geometries[i].generation = r.INVALID_ID
	}

	if !create_default_geometry(geo_state_ptr) {
		l.log_fatal("Failed to create default geometry. Application cannot continue.")
		return false
	}

	return true
}

geometry_system_shutdown :: proc() {
	if geo_state_ptr != nil {
		// Destroy all loaded geometries.
		for i in 0 ..< geo_state_ptr.config.max_geometry_count {
			g := &geo_state_ptr.registered_geometries[i]
			if g.id != r.INVALID_ID {
				destroy_geometry(g)
			}
		}
		destroy_geometry(&geo_state_ptr.default_geometry)
		delete(geo_state_ptr.registered_geometries)
		delete(geo_state_ptr.geometry_references)
		geo_state_ptr = nil
	}
}

geometry_system_acquire_from_config :: proc(
	vertex_count: u32,
	vertices: []okmath.vertex_3d,
	index_count: u32,
	indices: []u32,
	name: string,
	material_name: string,
	auto_release: bool,
) -> ^r.geometry {
	g: ^r.geometry = nil
	for i in 0 ..< geo_state_ptr.config.max_geometry_count {
		if geo_state_ptr.registered_geometries[i].id == r.INVALID_ID {
			// Found empty slot.
			geo_state_ptr.geometry_references[i].auto_release = auto_release
			geo_state_ptr.geometry_references[i].reference_count = 1
			g = &geo_state_ptr.registered_geometries[i]
			g.id = i
			break
		}
	}

	if g == nil {
		l.log_error(
			"Unable to obtain free slot for geometry. Adjust configuration to allow more space. Returning nil.",
		)
		return nil
	}

	if !create_geometry(g, vertex_count, vertices, index_count, indices, name, material_name) {
		l.log_error("Failed to create geometry. Returning nil.")
		return nil
	}

	return g
}

geometry_system_acquire_by_id :: proc(id: u32) -> ^r.geometry {
	if id != r.INVALID_ID && geo_state_ptr.registered_geometries[id].id != r.INVALID_ID {
		geo_state_ptr.geometry_references[id].reference_count += 1
		return &geo_state_ptr.registered_geometries[id]
	}
	l.log_error("geometry_system_acquire_by_id cannot load invalid geometry id. Returning nil.")
	return nil
}

geometry_system_release :: proc(geom: ^r.geometry) {
	if geom != nil && geom.id != r.INVALID_ID {
		ref := &geo_state_ptr.geometry_references[geom.id]
		id := geom.id
		if geo_state_ptr.registered_geometries[id].id == geom.id {
			if ref.reference_count > 0 {
				ref.reference_count -= 1
			}
			if ref.reference_count < 1 && ref.auto_release {
				destroy_geometry(&geo_state_ptr.registered_geometries[id])
				ref.reference_count = 0
				ref.auto_release = false
			}
		} else {
			l.log_fatal("Geometry id mismatch. Check registration logic, as this should never occur.")
		}
		return
	}
	l.log_warning("geometry_system_release cannot release invalid geometry id. Nothing was done.")
}

geometry_system_get_default :: proc() -> ^r.geometry {
	if geo_state_ptr != nil {
		return &geo_state_ptr.default_geometry
	}
	l.log_fatal("geometry_system_get_default called before system was initialized. Returning nil.")
	return nil
}

geometry_system_generate_plane_config :: proc(
	width: f32,
	height: f32,
	x_segment_count: u32,
	y_segment_count: u32,
	tile_x: f32,
	tile_y: f32,
) -> ([]okmath.vertex_3d, []u32) {
	w := width
	h := height
	xsc := x_segment_count
	ysc := y_segment_count
	tx := tile_x
	ty := tile_y

	if w == 0 {
		l.log_warning("Width must be nonzero. Defaulting to one.")
		w = 1.0
	}
	if h == 0 {
		l.log_warning("Height must be nonzero. Defaulting to one.")
		h = 1.0
	}
	if xsc < 1 {
		l.log_warning("x_segment_count must be a positive number. Defaulting to one.")
		xsc = 1
	}
	if ysc < 1 {
		l.log_warning("y_segment_count must be a positive number. Defaulting to one.")
		ysc = 1
	}
	if tx == 0 {
		l.log_warning("tile_x must be nonzero. Defaulting to one.")
		tx = 1.0
	}
	if ty == 0 {
		l.log_warning("tile_y must be nonzero. Defaulting to one.")
		ty = 1.0
	}

	vertex_count := xsc * ysc * 4 // 4 verts per segment
	index_count := xsc * ysc * 6  // 6 indices per segment

	vertices := make([]okmath.vertex_3d, vertex_count)
	indices := make([]u32, index_count)

	seg_width := w / f32(xsc)
	seg_height := h / f32(ysc)
	half_width := w * 0.5
	half_height := h * 0.5

	for y in 0 ..< ysc {
		for x in 0 ..< xsc {
			min_x := f32(x) * seg_width - half_width
			min_y := f32(y) * seg_height - half_height
			max_x := min_x + seg_width
			max_y := min_y + seg_height
			min_uvx := (f32(x) / f32(xsc)) * tx
			min_uvy := (f32(y) / f32(ysc)) * ty
			max_uvx := (f32(x + 1) / f32(xsc)) * tx
			max_uvy := (f32(y + 1) / f32(ysc)) * ty

			v_offset := (y * xsc + x) * 4
			vertices[v_offset + 0].position.x = min_x
			vertices[v_offset + 0].position.y = min_y
			vertices[v_offset + 0].texcoord.x = min_uvx
			vertices[v_offset + 0].texcoord.y = min_uvy

			vertices[v_offset + 1].position.x = max_x
			vertices[v_offset + 1].position.y = max_y
			vertices[v_offset + 1].texcoord.x = max_uvx
			vertices[v_offset + 1].texcoord.y = max_uvy

			vertices[v_offset + 2].position.x = min_x
			vertices[v_offset + 2].position.y = max_y
			vertices[v_offset + 2].texcoord.x = min_uvx
			vertices[v_offset + 2].texcoord.y = max_uvy

			vertices[v_offset + 3].position.x = max_x
			vertices[v_offset + 3].position.y = min_y
			vertices[v_offset + 3].texcoord.x = max_uvx
			vertices[v_offset + 3].texcoord.y = min_uvy

			i_offset := (y * xsc + x) * 6
			indices[i_offset + 0] = v_offset + 0
			indices[i_offset + 1] = v_offset + 1
			indices[i_offset + 2] = v_offset + 2
			indices[i_offset + 3] = v_offset + 0
			indices[i_offset + 4] = v_offset + 3
			indices[i_offset + 5] = v_offset + 1
		}
	}

	return vertices, indices
}

@(private = "file")
create_geometry :: proc(
	g: ^r.geometry,
	vertex_count: u32,
	vertices: []okmath.vertex_3d,
	index_count: u32,
	indices: []u32,
	name: string,
	material_name: string,
) -> bool {
	if !ren.renderer_create_geometry(g, vertex_count, vertices, index_count, indices) {
		// Invalidate the entry.
		if g.id != r.INVALID_ID {
			geo_state_ptr.geometry_references[g.id].reference_count = 0
			geo_state_ptr.geometry_references[g.id].auto_release = false
		}
		g.id = r.INVALID_ID
		g.generation = r.INVALID_ID
		g.internal_id = r.INVALID_ID
		return false
	}

	// Acquire the material.
	if len(material_name) > 0 {
		g.material = material_system_acquire(material_name)
		if g.material == nil {
			g.material = material_system_get_default()
		}
	}

	if len(name) > 0 {
		g.name = k.string_ncopy(name, r.GEOMETRY_NAME_MAX_LENGTH)
	}

	return true
}

@(private = "file")
destroy_geometry :: proc(g: ^r.geometry) {
	ren.renderer_destroy_geometry(g)
	g.internal_id = r.INVALID_ID
	g.generation = r.INVALID_ID
	g.id = r.INVALID_ID
	g.name = ""

	// Release the material.
	if g.material != nil && len(g.material.name) > 0 {
		material_system_release(g.material.name)
		g.material = nil
	}
}

@(private = "file")
create_default_geometry :: proc(state: ^geometry_system_state) -> bool {
	verts: [4]okmath.vertex_3d
	f :: 10.0

	verts[0].position.x = -0.5 * f
	verts[0].position.y = -0.5 * f
	verts[0].texcoord.x = 0.0
	verts[0].texcoord.y = 0.0

	verts[1].position.x = 0.5 * f
	verts[1].position.y = 0.5 * f
	verts[1].texcoord.x = 1.0
	verts[1].texcoord.y = 1.0

	verts[2].position.x = -0.5 * f
	verts[2].position.y = 0.5 * f
	verts[2].texcoord.x = 0.0
	verts[2].texcoord.y = 1.0

	verts[3].position.x = 0.5 * f
	verts[3].position.y = -0.5 * f
	verts[3].texcoord.x = 1.0
	verts[3].texcoord.y = 0.0

	indices: [6]u32 = {0, 1, 2, 0, 3, 1}

	if !ren.renderer_create_geometry(
		&state.default_geometry,
		4,
		verts[:],
		6,
		indices[:],
	) {
		l.log_fatal("Failed to create default geometry. Application cannot continue.")
		return false
	}

	// Acquire the default material.
	state.default_geometry.material = material_system_get_default()

	return true
}
