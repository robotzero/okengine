package core

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"

LOG_WARN_ENABLED :: true
LOG_INFO_ENABLED :: true
LOG_TRACE_ENABLED :: true

logger_system_state :: struct {
	initialized: bool,
}

@(private = "file")
state_ptr: ^logger_system_state

initialize_logging :: proc(memory_requirement: ^u64, state: ^$T) -> ^T {
	// initialize_logging :: proc() {
	// memory_requirement^ = size_of(state)
	if state == nil {
		return nil
	}

	state_ptr = state
	state_ptr.initialized = true

	log_info("info %f", 3.14)
	log_debug("debug %f", 3.14)
	log_fatal("fatal %f", 3.14)
	log_error("error %f", 3.14)
	log_warning("warning %f", 3.14)

	return state_ptr
}

shutdown_logging :: proc(state: ^$T) {
	// @TODO: clean up logging/write queued entries.
	state_ptr = nil
}

// @TOOD make buffered login systemd
@(private)
log_output :: proc(
	log_level: log.Level,
	message: string,
	location := #caller_location,
	args: ..any,
) {
	// out_message := make([]byte, 32000)
	// defer mem.zero_slice(out_message)

	out_message := fmt.tprintf(message, ..args)
	platform_console_write(log_level, out_message, location)
}

@(disabled = LOG_INFO_ENABLED == false)
log_info :: proc(message: string, args: ..any, location := #caller_location) {
	log_output(log.Level.Info, message, location, ..args)
}

@(disabled = ODIN_DEBUG == false)
log_debug :: proc(message: string, args: ..any, location := #caller_location) {
	log_output(log.Level.Debug, message, location, ..args)
}

log_fatal :: proc(message: string, args: ..any, location := #caller_location) {
	log_output(log.Level.Fatal, message, location, ..args)
}

log_error :: proc(message: string, args: ..any, location := #caller_location) {
	log_output(log.Level.Error, message, location, ..args)
}

@(disabled = LOG_WARN_ENABLED == false)
log_warning :: proc(message: string, args: ..any, location := #caller_location) {
	log_output(log.Level.Warning, message, location, ..args)
}

// rl_log_buf: []byte
// rl_log_callback :: proc "c" (logLevel: rl.TraceLogLevel, text: cstring, args: libc.va_list) {
//     context = runtime.default_context()
//     context.logger = logger

//     if rl_log_buf == nil {
//         rl_log_buf = make([]byte, 128)
//     }

//     defer mem.zero_slice(rl_log_buf)

//     n: int
//     for {
//         va := args
//         n = int(libc.vsnprintf(raw_data(rl_log_buf), len(rl_log_buf), text, &va))
//         if n < len(rl_log_buf) do break
//         log.infof("Resizing raylib log buffer from %m to %m", len(rl_log_buf), len(rl_log_buf)*2)
//         rl_log_buf, _ = mem.resize_bytes(rl_log_buf, len(rl_log_buf)*2)
//     }

//     level: log.Level
//     switch logLevel {
//     case .TRACE, .DEBUG:     level = .Debug
//     case .ALL, .NONE, .INFO: level = .Info
//     case .WARNING:           level = .Warning
//     case .ERROR:             level = .Error
//     case .FATAL:             level = .Fatal
//     }

//     formatted := string(rl_log_buf[:n])
//     log.log(level, formatted)
// }

