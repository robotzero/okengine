package core

import "core:log"
import "core:mem"
import "core:fmt"
import "engine:okmath"
import "core:os"

// Externally-defined function to create a game.
create_game_proc:: #type proc(out_game: ^game) -> bool
create_game: create_game_proc

/**
 * The main entry point of the application.
 */
main :: proc() {
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

	game_inst: game

    defer log.destroy_console_logger(context.logger)
	defer mem.free_all()
	defer shutdown_memory()
	defer mem.free(game_inst.state)
  	context.logger = log.create_console_logger(lowest, log_options)

	if !create_game(&game_inst) {
		log_fatal("Could not create game")
        os.exit(-1)

	}

	if game_inst.render == nil  || game_inst.update == nil || game_inst.initialize == nil || game_inst.on_resize == nil {
		log_fatal("The game's function pointers must be assinged!")
        os.exit(-2)
	}

	if !application_create(&game_inst) {
		log_info("application failed to create!")
        os.exit(1)
	}

	if !application_run() {
		log_info("application did not shutdown gracefully.")
        os.exit(2)
	}
}
