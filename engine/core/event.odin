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

system_event_code :: enum {
	// Shuts the application down on the next frame.
    EVENT_CODE_APPLICATION_QUIT = 0x01,

    // Keyboard key pressed.
    /* Context usage:
     * u16 key_code = data.data.u16[0];
     */
    EVENT_CODE_KEY_PRESSED = 0x02,

    // Keyboard key released.
    /* Context usage:
     * u16 key_code = data.data.u16[0];
     */
    EVENT_CODE_KEY_RELEASED = 0x03,

    // Mouse button pressed.
    /* Context usage:
     * u16 button = data.data.u16[0];
     */
    EVENT_CODE_BUTTON_PRESSED = 0x04,

    // Mouse button released.
    /* Context usage:
     * u16 button = data.data.u16[0];
     */
    EVENT_CODE_BUTTON_RELEASED = 0x05,

    // Mouse moved.
    /* Context usage:
     * u16 x = data.data.u16[0];
     * u16 y = data.data.u16[1];
     */
    EVENT_CODE_MOUSE_MOVED = 0x06,

    // Mouse moved.
    /* Context usage:
     * u8 z_delta = data.data.u8[0];
     */
    EVENT_CODE_MOUSE_WHEEL = 0x07,

    // Resized/resolution changed from the OS.
    /* Context usage:
     * u16 width = data.data.u16[0];
     * u16 height = data.data.u16[1];
     */
    EVENT_CODE_RESIZED = 0x08,

    MAX_EVENT_CODE = 0xFF,
}

event_code_entry :: struct {
	events: [dynamic]registered_event,
}

event_system_state :: struct {
	registered: [MAX_MESSAGE_CODES]event_code_entry,
}

registered_event :: struct {
	listener: rawptr,
	callback: #type proc (code: u16, sender: rawptr, listener_inst: rawptr, data: event_context),
}

is_initialized : bool = false
state : event_system_state

event_shutdown :: proc() {
	// @TODO is there a chance we override this range?
	for registered in state.registered {
		if registered.events != nil {
			cnt.darray_destroy(registered.events)
			// @TODO check if dynamic array is empty?
			// registered.events = nil
		}
	}
	// for i:u16 = 0; i < MAX_MESSAGE_CODES; i = i + 1 {
	// 	if state.registered[i].events != nil {
	// 		cnt.darray_destroy(state.registered[i].events)
	// 		state.registered[i].events = nil
	// 	}
	// }
}
