package testbed

import "core:fmt"
import "core:log"
import "core:runtime"
import "core:mem"

import l "../engine/core/logger"
import pl "../platform/linux"

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

	context.logger = log.create_console_logger(lowest, log_options)

    defer log.destroy_console_logger(context.logger)
	state: pl.platform_state
	if ok:= pl.platform_setup(&state, "OK Engine Testbed", 100, 100, 1280, 720); !ok {
		l.log_fatal("Fail")
	}

	l.log_info("info %f", 3.14)
	l.log_debug("debug %f", 3.14)
	l.log_fatal("fatal %f", 3.14)
	l.log_error("error %f", 3.14)
	l.log_warning("warning %f", 3.14)

	for pl.platform_pump_messages(&state) == false {
		// l.log_info("STILL ALIVE")
	}

	defer pl.platform_shutdown(&state)
}
