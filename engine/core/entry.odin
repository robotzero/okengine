package core

import app "../../engine/core/application"
import l "../../engine/core/logger"

main :: proc() {
	game_inst: app.game

	if !create_game(&game_inst) {
		l.log_fatal("Could not create game")
	}

	if !game_inst.render  || !game_inst.update || !game_inst.initialize || !game_inst.on_resize {
		l.log_fatal("The game's function pointers must be assinged!")
		// @TODO panic
	}

	if !application_create(&game_inst) {
		l.log_info("application failed to create!")
		// @TODO panic and create application_create to return error and use if ok pattern and force reuse return value
	}

	if !application_run() {
		l.log_info("application did not shutdown gracefully.")
	}

	// @TODO exit 0
}
