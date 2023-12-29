package testbed

import c "../engine/core"
import l "../engine/core/logger"

main :: proc() {
	game_inst: c.game

	if !create_game(&game_inst) {
		l.log_fatal("Could not create game")
	}

	if game_inst.render == nil  || game_inst.update == nil || game_inst.initialize == nil || game_inst.on_resize == nil {
		l.log_fatal("The game's function pointers must be assinged!")
		// @TODO panic
	}

	if !c.application_create(&game_inst) {
		l.log_info("application failed to create!")
		// @TODO panic and create application_create to return error and use if ok pattern and force reuse return value
	}

	if !c.application_run() {
		l.log_info("application did not shutdown gracefully.")
	}

	// @TODO exit 0
}
