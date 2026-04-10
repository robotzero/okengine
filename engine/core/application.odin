package core

import d "../containers"
import l "../logger"
import "../okmath"
import p "../platform/linux"
import ren "../renderer"
import res "../resources"
import sys "../systems"
import v "../renderer/vulkan"
import "core:mem"
import "core:mem/virtual"
import e "event"
import idef "input"

application_state :: struct {
	game_inst:                         ^game,
	is_running:                        bool,
	is_suspended:                      bool,
	platform:                          p.platform_system_state,
	width:                             i32,
	height:                            i32,
	c:                                 clock,
	last_time:                         f64,
	systems_allocator:                 linear_allocator,
	memory_system_memory_requirement:  u64,
	memory_system_state:               ^memory_system_state,
	logging_system_memory_requirement: u64,
	logging_system_state:              ^l.logger_system_state,
	platform_system_state:             ^p.platform_system_state,
	input_system_state:                ^input_system_state,
	event_system_state:                ^e.event_system_state,
	resource_system_state:             ^sys.resource_system_state,
	renderer_system_state:             ^ren.renderer_system_state,
	texture_system_state:              ^sys.texture_system_state,
	material_system_state:             ^sys.material_system_state,
	geometry_system_state:             ^sys.geometry_system_state,
	test_geometry:                     ^res.geometry,
}

application_config :: struct {
	start_pos_x:  i32,
	start_pos_y:  i32,
	start_width:  i32,
	start_height: i32,
	name:         string,
}

app_state: ^application_state

application_create :: proc(
	game_inst: ^game,
	sys_alloc: ^mem.Allocator,
	systems_allocator_total_size: uint,
) -> bool {
	if game_inst.application_state != nil {
		l.log_error("application called more than once")
		return false
	}

	game_inst.application_state = kallocate(memory_tag.MEMORY_TAG_APPLICATION, application_state)
	app_state = game_inst.application_state
	app_state.game_inst = game_inst
	app_state.is_running = false
	app_state.is_suspended = false

	linear_allocator_create(systems_allocator_total_size, &app_state.systems_allocator)

	// Initialize subsystems
	// Events
	event_state, err := linear_allocator_allocate(
		&app_state.systems_allocator,
		e.event_system_state,
		sys_alloc,
	)
	ensure(err == nil)
	e.event_system_initialize(event_state)
	app_state.event_system_state = event_state

	// Memory
	mem_state, mem_err := linear_allocator_allocate(
		&app_state.systems_allocator,
		memory_system_state,
		sys_alloc,
	)
	ensure(mem_err == nil)
	mem_state = memory_system_initialize(mem_state)
	app_state.memory_system_state = mem_state

	// Logging
	log_state, log_err := linear_allocator_allocate(
		&app_state.systems_allocator,
		l.logger_system_state,
		sys_alloc,
	)
	ensure(log_err == nil)

	logging_state := l.initialize_logging(&app_state.logging_system_memory_requirement, log_state)
	app_state.logging_system_state = logging_state

	// Input
	input_state, i_err := linear_allocator_allocate(
		&app_state.systems_allocator,
		input_system_state,
		sys_alloc,
	)
	ensure(i_err == nil)
	input_system_initialize(input_state)
	app_state.input_system_state = input_state

	e.event_register(
		u16(e.system_event_code.EVENT_CODE_APPLICATION_QUIT),
		nil,
		application_on_event,
	)
	e.event_register(u16(e.system_event_code.EVENT_CODE_KEY_PRESSED), nil, application_on_key)
	e.event_register(u16(e.system_event_code.EVENT_CODE_KEY_RELEASED), nil, application_on_key)
	e.event_register(u16(e.system_event_code.EVENT_CODE_RESIZED), nil, application_on_resized)

	// Platform
	platform_state, pl_err := linear_allocator_allocate(
		&app_state.systems_allocator,
		p.platform_system_state,
		sys_alloc,
	)
	app_state.platform_system_state = platform_state

	if ok := p.platform_system_startup(
		app_state.platform_system_state,
		game_inst.app_config.name,
		game_inst.app_config.start_pos_x,
		game_inst.app_config.start_pos_y,
		game_inst.app_config.start_width,
		game_inst.app_config.start_height,
		sys_alloc^,
	); !ok {
		return false
	}

	// Register input callbacks with platform layer
	app_state.platform_system_state.on_key = input_process_key
	app_state.platform_system_state.on_button = input_process_button
	app_state.platform_system_state.on_mouse_move = input_process_mouse_move

	// Resource System
	res_sys_config: sys.resource_system_config
	res_sys_config.asset_base_path = "bin/assets"
	res_sys_config.max_loader_count = 32

	rsstate, rserror := linear_allocator_allocate(
		&app_state.systems_allocator,
		sys.resource_system_state,
		sys_alloc,
	)

	app_state.resource_system_state = rsstate

	if !sys.resource_system_initialize(app_state.resource_system_state, res_sys_config) {
		l.log_fatal("Failed to initialize resource system. Aborting application.")
		return false
	}

	// Renderer
	r_state, r_error := linear_allocator_allocate(
		&app_state.systems_allocator,
		ren.renderer_system_state,
		sys_alloc,
	)
	app_state.renderer_system_state = r_state
	v.renderer_backend_create(
		ren.renderer_backend_type.RENDERER_BACKEND_TYPE_VULKAN,
		&r_state.backend,
	)
	if ok := ren.renderer_system_initialize(
		game_inst.app_config.name,
		r_state,
		u32(game_inst.app_config.start_width),
		u32(game_inst.app_config.start_height),
		sys_alloc^,
	); !ok {
		l.log_fatal("Failed to initialize renderer. Aborting application.")
		return false
	}

	// Register debug event
	e.event_register(
		u16(e.system_event_code.EVENT_CODE_DEBUG0),
		nil,
		application_on_debug_event,
	)

	// Texture system
	texture_sys_config: sys.texture_system_config
	texture_sys_config.max_texture_count = sys.MAX_TEXTURE_COUNT

	tstate, terror := linear_allocator_allocate(
		&app_state.systems_allocator,
		sys.texture_system_state,
		sys_alloc,
	)

	app_state.texture_system_state = tstate

	if !sys.texture_system_initialize(app_state.texture_system_state, texture_sys_config, sys_alloc^) {
		l.log_fatal("Failed to initialize texture system. Application cannot continue.")
		return false
	}

	// Material System
	material_sys_config: sys.material_system_config
	material_sys_config.max_material_count = 4096

	mstate, merror := linear_allocator_allocate(
		&app_state.systems_allocator,
		sys.material_system_state,
		sys_alloc,
	)

	app_state.material_system_state = mstate

	if !sys.material_system_initialize(
		app_state.material_system_state,
		material_sys_config,
		sys_alloc^,
	) {
		l.log_fatal("Failed to initialize material system. Application cannot continue.")
		return false
	}

	// Geometry System
	geometry_sys_config: sys.geometry_system_config
	geometry_sys_config.max_geometry_count = 4096

	gstate, gerror := linear_allocator_allocate(
		&app_state.systems_allocator,
		sys.geometry_system_state,
		sys_alloc,
	)

	app_state.geometry_system_state = gstate

	if !sys.geometry_system_initialize(app_state.geometry_system_state, geometry_sys_config) {
		l.log_fatal("Failed to initialize geometry system. Application cannot continue.")
		return false
	}

	if ok := app_state.game_inst.initialize(app_state.game_inst); !ok {
		return false
	}

	app_state.game_inst.on_resize(app_state.game_inst, app_state.width, app_state.height)

	return true
}

application_on_event :: proc(
	code: u16,
	sender: rawptr,
	listener: rawptr,
	data: e.event_context,
) -> bool {
	switch code {
	case u16(e.system_event_code.EVENT_CODE_APPLICATION_QUIT):
		{
			l.log_info("EVENT_CODE_APPLICATION_QUIT received, shutting down. \n")
			app_state.is_running = false
			return true
		}
	}
	return false
}

application_on_key :: proc(
	code: u16,
	sender: rawptr,
	listener: rawptr,
	data: e.event_context,
) -> bool {
	if code == u16(e.system_event_code.EVENT_CODE_KEY_PRESSED) {
		event_context_data := data.data.([8]u16)
		key_code: u16 = event_context_data[0]
		if key_code == u16(idef.keys.KEY_ESCAPE) {
			event_context_data_new: e.event_context = {}
			e.event_fire(
				u16(e.system_event_code.EVENT_CODE_APPLICATION_QUIT),
				nil,
				event_context_data_new,
			)

			// Block anything else from processing this.
			return true
		} else if key_code == u16(idef.keys.KEY_A) {
			// Checking if it is working
			l.log_debug("Explicit - A key pressed!")
		} else {
			l.log_debug("'%c' key pressed in a window.", key_code)
		}
	} else if code == u16(e.system_event_code.EVENT_CODE_KEY_RELEASED) {
		if event_context_data, ok := data.data.([8]u16); ok {
			key_code: u16 = event_context_data[0]
			if key_code == u16(idef.keys.KEY_B) {
				l.log_debug("Explicit B key released")
			} else {
				l.log_debug("'%c' key released in window.", key_code)
			}
		} else {
			l.log_fatal("Event data not correct type!")
		}
	}
	return false
}

application_on_resized :: proc(
	code: u16,
	sender: rawptr,
	listener: rawptr,
	data: e.event_context,
) -> bool {
	if code == u16(e.system_event_code.EVENT_CODE_RESIZED) {
		event_context_data := data.data.([8]u16)
		width: u16 = event_context_data[0]
		height: u16 = event_context_data[1]

		if i32(width) != app_state.width || i32(height) != app_state.height {
			app_state.width = i32(width)
			app_state.height = i32(height)

			l.log_debug("Window resize: %i, %i", width, height)

			// Handle minimization
			if width == 0 || height == 0 {
				l.log_info("Window minimized, suspending application.")
				app_state.is_suspended = true
				return true
			} else {
				if app_state.is_suspended {
					l.log_info("Window restored, resuming application.")
					app_state.is_suspended = false
				}
				app_state.game_inst.on_resize(app_state.game_inst, i32(width), i32(height))
				ren.renderer_on_resized(width, height)
			}
		}
	}

	// Event purposely not handled to allow other listeners to get this.
	return false
}

@(private = "file")
debug_choice: i8 = 2

application_on_debug_event :: proc(
	code: u16,
	sender: rawptr,
	listener_inst: rawptr,
	data: e.event_context,
) -> bool {
	names := [3]string{"cobblestone", "paving", "paving2"}

	// Save off the old name
	old_name := names[debug_choice]

	debug_choice = debug_choice + 1
	debug_choice %= 3

	mat: ^res.material = nil
	if app_state.test_geometry != nil {
		mat = app_state.test_geometry.material
	}
	if mat != nil {
		// Acquire the new texture
		mat.diffuse_map.texture = sys.texture_system_acquire(names[debug_choice], true)

		if mat.diffuse_map.texture == nil {
			l.log_info("application_on_debug_event no texture! using default")
			mat.diffuse_map.texture = sys.texture_system_get_default_texture()
		}
		// Release the old texture
		sys.texture_system_release(old_name)
	}
	return true
}

application_run :: proc() -> bool {
	defer memory_system_shutdown(app_state.memory_system_state)
	defer p.platform_system_shutdown(app_state.platform_system_state)
	defer ren.renderer_system_shutdown(app_state.renderer_system_state)
	defer sys.texture_system_shutdown()
	defer sys.material_system_shutdown()
	defer sys.geometry_system_shutdown()
	defer sys.resource_system_shutdown()
	defer input_system_shutdown(app_state.input_system_state)
	defer e.event_system_shutdown(app_state.event_system_state)
	defer e.event_unregister(
		u16(e.system_event_code.EVENT_CODE_APPLICATION_QUIT),
		nil,
		application_on_event,
	)
	defer e.event_unregister(
		u16(e.system_event_code.EVENT_CODE_KEY_PRESSED),
		nil,
		application_on_key,
	)
	defer e.event_unregister(
		u16(e.system_event_code.EVENT_CODE_KEY_RELEASED),
		nil,
		application_on_key,
	)
	defer e.event_unregister(
		u16(e.system_event_code.EVENT_CODE_DEBUG0),
		nil,
		application_on_debug_event,
	)
	defer app_state.is_running = false

	app_state.is_running = true
	clock_start(&app_state.c)
	clock_update(&app_state.c)
	app_state.last_time = app_state.c.elapsed
	running_time: f64 = 0
	frame_count: u8 = 0
	target_frame_seconds: f64 = 1.0 / 60

	mem_info := get_memory_usage_str()
	defer delete(mem_info)
	l.log_info(mem_info)

	for app_state.is_running {
		if !p.platform_pump_messages() {
			app_state.is_running = false
		}

		if !app_state.is_suspended {
			// Update clock and get delta time
			clock_update(&app_state.c)
			current_time: f64 = app_state.c.elapsed
			delta: f64 = current_time - app_state.last_time
			frame_start_time: f64 = p.platform_get_absolute_time()

			if !app_state.game_inst.update(app_state.game_inst, f32(delta)) {
				l.log_fatal("Game update failed, shutting down.")
				app_state.is_running = false
				break
			}

			if !app_state.game_inst.render(app_state.game_inst, f32(delta)) {
				l.log_fatal("Game render failed, shutting down.")
				app_state.is_running = false
				break
			}

			// Prepare render data
			if app_state.test_geometry == nil {
				// Generate a test plane geometry
				vertices, indices := sys.geometry_system_generate_plane_config(
					10.0,
					10.0,
					1,
					1,
					1.0,
					1.0,
				)
				app_state.test_geometry = sys.geometry_system_acquire_from_config(
					u32(len(vertices)),
					vertices,
					u32(len(indices)),
					indices,
					"test_geometry",
					"test_material",
					false,
				)
				delete(vertices)
				delete(indices)
				if app_state.test_geometry == nil {
					l.log_warning(
						"Geometry creation failed, using default geometry.",
					)
					app_state.test_geometry = sys.geometry_system_get_default()
				}
			}

			// TODO: refactor packet creation
			packet: ren.render_packet
			packet.delta_time = f32(delta)
			model := okmath.mat4_translation(okmath.vec3{0, 0, 0})
			geo_data := ren.geometry_render_data {
				model    = model,
				geometry = app_state.test_geometry,
			}
			objects := [1]ren.geometry_render_data{geo_data}
			packet.geometry_count = 1
			packet.geometries = objects[:]
			ren.renderer_draw_frame(&packet)

			// Figure out how long the frame took and, if below
			frame_end_time: f64 = p.platform_get_absolute_time()
			frame_elapsed_time: f64 = frame_end_time - frame_start_time
			running_time += frame_elapsed_time
			remaining_seconds: f64 = target_frame_seconds - frame_elapsed_time

			if remaining_seconds > 0 {
				remaining_ms: f64 = remaining_seconds * 1000

				// If there is a time left, give it back to the OS.
				limit_frames := false
				if remaining_seconds > 0 && limit_frames {
					p.platform_sleep(remaining_ms - 1)
				}

				frame_count = frame_count + 1
			}

			// NOTE: Input update/state copying should always be handled
			// after any input should be recorded; I.E. before this line.
			// As a safety, input is the last thing to be updated before
			// this frame ends.
			input_update(cast(f64)delta)

			// Update last time
			app_state.last_time = current_time
		}
	}

	app_state.is_running = false

	return true
}

application_get_framebuffer_size :: proc(width: ^u32, height: ^u32) {
	width^ = cast(u32)app_state.width
	height^ = cast(u32)app_state.height
}
