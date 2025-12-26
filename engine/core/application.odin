package core

import d "../containers"
import "core:mem"
import "core:mem/virtual"
import idef "input"

application_state :: struct {
	game_inst:                         ^game,
	is_running:                        bool,
	is_suspended:                      bool,
	platform:                          platform_system_state,
	width:                             i32,
	height:                            i32,
	c:                                 clock,
	last_time:                         i64,
	systems_allocator:                 linear_allocator,
	memory_system_memory_requirement:  u64,
	memory_system_state:               ^memory_system_state,
	logging_system_memory_requirement: u64,
	logging_system_state:              ^logger_system_state,
	platform_system_state:             ^platform_system_state,
	input_system_state:                ^input_system_state,
	event_system_state:                ^event_system_state,
	renderer_system_state:             ^renderer_system_state,
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
		log_error("application called more than once")
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
		event_system_state,
		sys_alloc,
	)
	ensure(err == nil)
	event_system_initialize(event_state)
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
		logger_system_state,
		sys_alloc,
	)
	ensure(log_err == nil)

	logging_state := initialize_logging(&app_state.logging_system_memory_requirement, log_state)
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

	event_register(
		cast(u16)system_event_code.EVENT_CODE_APPLICATION_QUIT,
		nil,
		application_on_event,
	)
	event_register(cast(u16)system_event_code.EVENT_CODE_KEY_PRESSED, nil, application_on_key)
	event_register(cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED, nil, application_on_key)
	event_register(cast(u16)system_event_code.EVENT_CODE_RESIZED, nil, application_on_resized)

	// Platform
	platform_state, pl_err := linear_allocator_allocate(
		&app_state.systems_allocator,
		platform_system_state,
		sys_alloc,
	)
	app_state.platform_system_state = platform_state

	if ok := platform_system_startup(
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

	// Renderer
	r_state, r_error := linear_allocator_allocate(
		&app_state.systems_allocator,
		renderer_system_state,
		sys_alloc,
	)
	app_state.renderer_system_state = r_state
	if ok := renderer_system_initialize(game_inst.app_config.name, r_state); !ok {
		log_fatal("Failed to initialize renderer. Aborting application.")
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
	data: event_context,
) -> bool {
	switch code {
	case cast(u16)system_event_code.EVENT_CODE_APPLICATION_QUIT:
		{
			log_info("EVENT_CODE_APPLICATION_QUIT received, shutting down. \n")
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
	data: event_context,
) -> bool {
	if code == cast(u16)system_event_code.EVENT_CODE_KEY_PRESSED {
		event_context_data := data.data.([2]u16)
		key_code: u16 = event_context_data[0]
		if key_code == cast(u16)idef.keys.KEY_ESCAPE {
			event_context_data_new: event_context = {}
			event_fire(
				cast(u16)system_event_code.EVENT_CODE_APPLICATION_QUIT,
				nil,
				event_context_data_new,
			)

			// Block anything else from processing this.
			return true
		} else if key_code == cast(u16)idef.keys.KEY_A {
			// Checking if it is working
			log_debug("Explicit - A key pressed!")
		} else {
			log_debug("'%c' key pressed in a window.", key_code)
		}
	} else if code == cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED {
		if event_context_data, ok := data.data.([2]u16); ok {
			key_code: u16 = event_context_data[0]
			if key_code == cast(u16)idef.keys.KEY_B {
				log_debug("Explicit B key released")
			} else {
				log_debug("'%c' key released in window.", key_code)
			}
		} else {
			log_fatal("Event data not correct type!")
		}
	}
	return false
}

application_on_resized :: proc(
	code: u16,
	sender: rawptr,
	listener: rawptr,
	data: event_context,
) -> bool {
	if code == cast(u16)system_event_code.EVENT_CODE_RESIZED {
		event_context_data := data.data.([2]u16)
		width: u16 = event_context_data[0]
		height: u16 = event_context_data[1]

		if cast(i32)width != app_state.width || cast(i32)height != app_state.height {
			app_state.width = cast(i32)width
			app_state.height = cast(i32)height

			log_debug("Window resize: %i, %i", width, height)

			// Handle minimization
			if width == 0 || height == 0 {
				log_info("Window minimized, suspending application.")
				app_state.is_suspended = true
				return true
			} else {
				if app_state.is_suspended {
					log_info("Window restored, resuming application.")
					app_state.is_suspended = false
				}
				app_state.game_inst.on_resize(app_state.game_inst, cast(i32)width, cast(i32)height)
				renderer_on_resized(width, height)
			}
		}
	}

	// Event purposely not handled to allow other listeners to get this.
	return false
}

application_run :: proc() -> bool {
	defer memory_system_shutdown(app_state.memory_system_state)
	defer platform_system_shutdown(app_state.platform_system_state)
	defer renderer_system_shutdown(app_state.renderer_system_state)
	defer input_system_shutdown(app_state.input_system_state)
	defer event_system_shutdown(app_state.event_system_state)
	defer event_unregister(
		cast(u16)system_event_code.EVENT_CODE_APPLICATION_QUIT,
		nil,
		application_on_event,
	)
	defer event_unregister(
		cast(u16)system_event_code.EVENT_CODE_KEY_PRESSED,
		nil,
		application_on_key,
	)
	defer event_unregister(
		cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED,
		nil,
		application_on_key,
	)
	defer app_state.is_running = false

	app_state.is_running = true
	clock_start(&app_state.c)
	clock_update(&app_state.c)
	app_state.last_time = app_state.c.elapsed
	running_time: i64 = 0
	frame_count: u8 = 0
	target_frame_seconds: f64 = 1.0 / 60

	mem_info := get_memory_usage_str()
	defer delete(mem_info)
	log_info(mem_info)

	for app_state.is_running {
		if !platform_pump_messages() {
			app_state.is_running = false
		}

		if !app_state.is_suspended {
			// Update clock and get delta time
			clock_update(&app_state.c)
			current_time: i64 = app_state.c.elapsed
			delta: i64 = current_time - app_state.last_time
			frame_start_time: i64 = platform_get_absolute_time()

			if !app_state.game_inst.update(app_state.game_inst, 0.0) {
				log_fatal("Game update failed, shutting down.")
				app_state.is_running = false
				break
			}

			if !app_state.game_inst.render(app_state.game_inst, cast(f32)delta) {
				log_fatal("Game render failed, shutting down.")
				app_state.is_running = false
				break
			}

			// TODO: refactor packet creation
			packet: render_packet
			packet.delta_time = cast(f32)delta
			renderer_draw_frame(&packet)

			// Figure out how long the frame took and, if below
			frame_end_time: i64 = platform_get_absolute_time()
			frame_elapsed_time: i64 = frame_end_time - frame_start_time
			running_time += frame_elapsed_time
			remaining_seconds: f64 = target_frame_seconds - cast(f64)frame_elapsed_time

			if remaining_seconds > 0 {
				remaining_ms: f64 = remaining_seconds * 1000

				// If there is a time left, give it back to the OS.
				limit_frames := false
				if remaining_seconds > 0 && limit_frames {
					platform_sleep(remaining_ms - 1)
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

