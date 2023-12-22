package testbed

import "core:fmt"
import l "../engine/core/logger"
import pl "../platform/linux"
import "core:log"
import "core:runtime"

// initialize_logging :: proc() {
// 	log_options := log.Options {
// 		.Level,
// 		.Time,
// 		.Line,
// 		.Short_File_Path,
// 		.Terminal_Color,
// 		.Procedure,
// 	}

// 	when ODIN_DEBUG {
// 		lowest :: log.Level.Debug
// 	} else {
// 		lowest :: log.Level.Info
// 	}

// 	// context = runtime.default_context()
// 	context.logger = log.create_console_logger(lowest, log_options)
// }

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
	} else {
		lowest :: log.Level.Info
	}

	context.logger = log.create_console_logger(lowest, log_options)
    defer log.destroy_console_logger(context.logger)
	l.log_debug("debug")
	pl.platform_setup()
}
