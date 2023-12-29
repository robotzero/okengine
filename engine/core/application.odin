package core

import l "logger"
import pl "../../platform/linux"

application_state :: struct {
	game_inst: ^game,
	is_running: bool,
	is_suspended: bool,
	platform: pl.platform_state,
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
		l.log_error("application called more than once")
		return false
	}

	app_state.game_inst = game_inst

	l.initialize_logging()
	
	l.log_info("info %f", 3.14)
	l.log_debug("debug %f", 3.14)
	l.log_fatal("fatal %f", 3.14)
	l.log_error("error %f", 3.14)
	l.log_warning("warning %f", 3.14)

	app_state.is_running = true
	app_state.is_suspended = false

	if !pl.platform_startup(
		&app_state.platform,
		game_inst.app_config.name,
		game_inst.app_config.start_pos_x,
		game_inst.app_config.start_pos_y,
		game_inst.app_config.start_width,
		game_inst.app_config.start_height,
	) {
			return false
	}

	if !app_state.game_inst.initialize(app_state.game_inst) {
		return false
	}

	app_state.game_inst.on_resize(app_state.game_inst, app_state.width, app_state.height)

	initialized = true

	return true
}

application_run :: proc() -> bool {
	defer pl.platform_shutdown(&app_state.platform)
	defer pl.platform_free(app_state.game_inst.state)

	for app_state.is_running {
		if pl.platform_pump_messages(&app_state.platform) {
			app_state.is_running = false
		}

		if !app_state.is_suspended {
			if !app_state.game_inst.update(app_state.game_inst, 0.0) {
				l.log_fatal("Game update failed, shutting down.")
				app_state.is_running = false
				//@TODO make sure we are breaking here like (break or continue)
			}

			if !app_state.game_inst.render(app_state.game_inst, 0.0) {
				l.log_fatal("Game render failed, shutting down.")
				app_state.is_running = false
			}
		}
	}
	app_state.is_running = false

	return true
}
