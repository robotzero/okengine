package testbed

import c "engine:core"
import "core:log"
import "core:mem"
import "core:fmt"
import "engine:okmath"

main :: proc() {

	c.initialize_memory()

	log_options := log.Options {
		.Level,
		.Time,
		.Line,
		.Short_File_Path,
		.Terminal_Color,
		.Procedure,
	}

	when ODIN_DEBUG {
		lowest :: log.Level.Debug
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	} else {
		lowest :: log.Level.Info
	}

	context.logger = log.create_console_logger(lowest, log_options)

    defer log.destroy_console_logger(context.logger)
	game_inst: c.game
	if !create_game(&game_inst) {
		c.log_fatal("Could not create game")
	}

	if game_inst.render == nil  || game_inst.update == nil || game_inst.initialize == nil || game_inst.on_resize == nil {
		c.log_fatal("The game's function pointers must be assinged!")
		// @TODO panic
	}

	if !c.application_create(&game_inst) {
		c.log_info("application failed to create!")
		// c.app_state.is_running = false
		// @TODO panic and create application_create to return error and use if ok pattern and force reuse return value
	}

	if !c.application_run() {
		c.log_info("application did not shutdown gracefully.")
	}
	defer mem.free_all()
	defer c.shutdown_memory()
	defer mem.free(game_inst.state)
	// @TODO exit 0
}
