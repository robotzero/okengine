package core

import d "../containers"
import idef "input"

application_state :: struct {
	game_inst: ^game,
	is_running: bool,
	is_suspended: bool,
	platform: platform_state,
	width: i32,
	height: i32,
	last_time: f64,
}

application_config :: struct {
	start_pos_x: i32,
	start_pos_y: i32,
	start_width: i32,
	start_height: i32,
	name: string,
}

initialized: bool = false
app_state: application_state

application_create :: proc(game_inst: ^game) -> bool {
	if initialized {
		log_error("application called more than once")
		return false
	}

	app_state.game_inst = game_inst

	initialize_logging()
	input_initialize()
	
	log_info("info %f", 3.14)
	log_debug("debug %f", 3.14)
	log_fatal("fatal %f", 3.14)
	log_error("error %f", 3.14)
	log_warning("warning %f", 3.14)

	app_state.is_running = true
	app_state.is_suspended = false

	if ok: = event_initialize(); !ok {
		log_error("Event system failed initialization. Application cannot continue.")
		return false
	}

	event_register(cast(u16)system_event_code.EVENT_CODE_APPLICATION_QUIT, nil, application_on_event)
	event_register(cast(u16)system_event_code.EVENT_CODE_KEY_PRESSED, nil, application_on_key)
	event_register(cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED, nil, application_on_key)

	if ok: = platform_startup(
		&app_state.platform,
		game_inst.app_config.name,
		game_inst.app_config.start_pos_x,
		game_inst.app_config.start_pos_y,
		game_inst.app_config.start_width,
		game_inst.app_config.start_height,
	); !ok {
			return false
	}

	if ok:= app_state.game_inst.initialize(app_state.game_inst); !ok {
		return false
	}

	app_state.game_inst.on_resize(app_state.game_inst, app_state.width, app_state.height)

	initialized = true

	return true
}

application_on_event :: proc (code: u16, sender: rawptr, listener: rawptr, data: event_context) -> bool {
	switch code {
		case cast(u16)system_event_code.EVENT_CODE_APPLICATION_QUIT: {
			log_info("EVENT_CODE_APPLICATION_QUIT received, shutting down. \n")
			app_state.is_running = false
			return true
		}
	}
	return false
}

application_on_key :: proc (code: u16, sender: rawptr, listener: rawptr, data: event_context) -> bool {
	if code == cast(u16)system_event_code.EVENT_CODE_KEY_PRESSED {
		event_context_data := data.data.([2]u16)
		key_code: u16 = event_context_data[0]
		if key_code == cast(u16)idef.keys.KEY_ESCAPE {
			event_context_data_new: event_context = {}
			event_fire(cast(u16)system_event_code.EVENT_CODE_APPLICATION_QUIT, nil, event_context_data_new)

			// Block anything else from processing this.
			return true
		} else if key_code == cast(u16)idef.keys.KEY_A {
			// Checking if it is working
			log_debug("Explicit - A key pressed!")
		} else {
			log_debug("'%c key pressed in a window.'", key_code)
		}
	} else if code == cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED {
		event_context_data := data.data.([2]u16)
		key_code: u16 = event_context_data[0]
		if key_code == cast(u16)idef.keys.KEY_B {
			log_debug("Explicit B key released")
		} else {
			log_debug("'%c' key released in window.", key_code)
		}
	}
	return false
}

application_run :: proc() -> bool {
	defer platform_shutdown(&app_state.platform)
	// defer platform_free(&app_state.game_inst.state)
	defer input_shutdown()
	defer event_shutdown()
	defer event_unregister(cast(u16)system_event_code.EVENT_CODE_APPLICATION_QUIT, nil, application_on_event)
	defer event_unregister(cast(u16)system_event_code.EVENT_CODE_KEY_PRESSED, nil, application_on_key)
	defer event_unregister(cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED, nil, application_on_key)
	defer app_state.is_running = false

	mem_info := get_memory_usage_str()
	defer delete(mem_info)
	log_info(mem_info)

	for app_state.is_running {
		if platform_pump_messages(&app_state.platform) {
			app_state.is_running = false
		}

		if !app_state.is_suspended {
			if !app_state.game_inst.update(app_state.game_inst, 0.0) {
				log_fatal("Game update failed, shutting down.")
				app_state.is_running = false
				break
			}

			if !app_state.game_inst.render(app_state.game_inst, 0.0) {
				log_fatal("Game render failed, shutting down.")
				app_state.is_running = false
				break
			}
			// NOTE: Input update/state copying should always be handled
            // after any input should be recorded; I.E. before this line.
            // As a safety, input is the last thing to be updated before
            // this frame ends.
            input_update(0)
		}
	}

	return true
}
