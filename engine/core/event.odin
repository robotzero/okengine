package core

import cnt "../containers"

MAX_MESSAGE_CODES :: 16384

event_context :: struct {
	data: union {
		[2]i64,
		[2]u64,
		[2]f64,
		[2]i32,
		[2]u32,
		[2]f32,
		[2]i16,
		[2]u16,
		[2]i8,
		[2]u8,
		[16]rune,
	},
}

system_event_code :: enum u16 {
	// Shuts the application down on the next frame.
	EVENT_CODE_APPLICATION_QUIT = 0x01,

	// Keyboard key pressed.
	/* Context usage:
     * u16 key_code = data.data.u16[0];
     */
	EVENT_CODE_KEY_PRESSED      = 0x02,

	// Keyboard key released.
	/* Context usage:
     * u16 key_code = data.data.u16[0];
     */
	EVENT_CODE_KEY_RELEASED     = 0x03,

	// Mouse button pressed.
	/* Context usage:
     * u16 button = data.data.u16[0];
     */
	EVENT_CODE_BUTTON_PRESSED   = 0x04,

	// Mouse button released.
	/* Context usage:
     * u16 button = data.data.u16[0];
     */
	EVENT_CODE_BUTTON_RELEASED  = 0x05,

	// Mouse moved.
	/* Context usage:
     * u16 x = data.data.u16[0];
     * u16 y = data.data.u16[1];
     */
	EVENT_CODE_MOUSE_MOVED      = 0x06,

	// Mouse moved.
	/* Context usage:
     * u8 z_delta = data.data.u8[0];
     */
	EVENT_CODE_MOUSE_WHEEL      = 0x07,

	// Resized/resolution changed from the OS.
	/* Context usage:
     * u16 width = data.data.u16[0];
     * u16 height = data.data.u16[1];
     */
	EVENT_CODE_RESIZED          = 0x08,
	MAX_EVENT_CODE              = 0xFF,
}

event_code_entry :: struct {
	events: [dynamic]registered_event,
}

event_system_state :: struct {
	registered: [MAX_MESSAGE_CODES]event_code_entry,
}

PFN_on_event :: #type proc(
	code: u16,
	sender: rawptr,
	listener_inst: rawptr,
	data: event_context,
) -> bool

registered_event :: struct {
	listener: rawptr,
	callback: PFN_on_event,
}

is_initialized: bool = false
state: event_system_state

event_initialize :: proc() -> bool {
	if is_initialized == true {
		return false
	}

	is_initialized = false
	kzero_memory(&state, size_of(state))
	is_initialized = true

	return true
}

event_register :: proc(code: u16, listener: rawptr, on_event: PFN_on_event) -> bool {
	if is_initialized == false {
		return false
	}

	if state.registered[code].events == nil {
		state.registered[code].events = cnt.darray_create_default(registered_event)
	}

	registered_counts := cnt.darray_length(state.registered[code].events)

	for v, _ in state.registered[code].events {
		if v.listener == listener {
			return false
		}
	}

	// If at this point not duplicate was found, proceed with registration.
	event: registered_event
	event.listener = listener
	event.callback = on_event
	cnt.darray_push(&state.registered[code].events, event)

	return true
}

event_unregister :: proc(code: u16, listener: rawptr, on_event: PFN_on_event) -> bool {
	if is_initialized == false {
		return false
	}

	// On nothing is registered for the code, boot out.
	if state.registered[code].events == nil {
		return false
	}

	for v, index in state.registered[code].events {
		if v.listener == listener && v.callback == on_event {
			// Found it, remove it
			cnt.darray_pop_at(&state.registered[code].events, index)
			return true
		}
	}

	return false
}

event_fire :: proc(code: u16, sender: rawptr, ev_context: event_context) -> bool {
	if is_initialized == false {
		return false
	}

	if state.registered[code].events == nil {
		return false
	}

	for v, _ in state.registered[code].events {
		if v.callback(code, sender, v.listener, ev_context) {
			return true
		}
	}

	// Not found
	return false
}

event_shutdown :: proc() {
	for &v, index in &state.registered {
		if v.events != nil {
			cnt.darray_destroy(v.events)
			v.events = nil
		}
	}
}

