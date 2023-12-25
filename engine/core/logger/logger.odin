package logger

import "core:log"
import "core:runtime"
import "core:mem"
import "core:fmt"

LOG_WARN_ENABLED  :: true
LOG_INFO_ENABLED  :: true
LOG_TRACE_ENABLED :: true

shutdown_logging :: proc() {
	
}
// @TOOD make buffered login system

@(private)
log_output :: proc(log_level: log.Level, message: cstring, location := #caller_location) {
	// out_message := make([]byte, 32000)
	// defer mem.zero_slice(out_message)
	log.log(log_level, message, location = location)
}

@(disabled = LOG_INFO_ENABLED == false)
log_info :: proc(message: cstring, location := #caller_location) {
	log_output(log.Level.Info, message, location)
}

@(disabled = ODIN_DEBUG == false)
log_debug :: proc(message: cstring, location := #caller_location) {
	log_output(log.Level.Debug, message, location)
}

log_fatal :: proc(message: cstring, location := #caller_location) {
	log_output(log.Level.Fatal, message, location)
}

log_error :: proc(message: cstring, location := #caller_location) {
	log_output(log.Level.Error, message, location)
}

@(disabled = LOG_WARN_ENABLED == false)
log_warning :: proc(message: cstring, location := #caller_location) {
	log_output(log.Level.Warning, message, location)
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
