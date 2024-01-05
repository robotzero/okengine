package core

import l "logger"

BUTTON_MAX_BUTTONS :: 3
KEYS_MAX_KEYS :: 125

buttons :: enum {
	BUTTON_LEFT,
	BUTTON_RIGHT,
	BUTTON_MIDDLE,
}

keys :: enum u16 {
	KEY_BACKSPACE = 0x08,
    KEY_ENTER = 0x0D,
    KEY_TAB = 0x09,
    KEY_SHIFT = 0x10,
    KEY_CONTROL = 0x11,

    KEY_PAUSE = 0x13,
    KEY_CAPITAL = 0x14,

    KEY_ESCAPE = 0x1B,

    KEY_CONVERT = 0x1C,
    KEY_NONCONVERT = 0x1D,
    KEY_ACCEPT = 0x1E,
    KEY_MODECHANGE = 0x1F,

    KEY_SPACE = 0x20,
    KEY_PRIOR = 0x21,
    KEY_NEXT = 0x22,
    KEY_END = 0x23,
    KEY_HOME = 0x24,
    KEY_LEFT = 0x25,
    KEY_UP = 0x26,
    KEY_RIGHT = 0x27,
    KEY_DOWN = 0x28,
    KEY_SELECT = 0x29,
    KEY_PRINT = 0x2A,
    KEY_EXECUTE = 0x2B,
    KEY_SNAPSHOT = 0x2C,
    KEY_INSERT = 0x2D,
    KEY_DELETE = 0x2E,
    KEY_HELP = 0x2F,

    KEY_A = 0x41,
    KEY_B = 0x42,
    KEY_C = 0x43,
    KEY_D = 0x44,
    KEY_E = 0x45,
    KEY_F = 0x46,
    KEY_G = 0x47,
    KEY_H = 0x48,
    KEY_I = 0x49,
    KEY_J = 0x4A,
    KEY_K = 0x4B,
    KEY_L = 0x4C,
    KEY_M = 0x4D,
    KEY_N = 0x4E,
    KEY_O = 0x4F,
    KEY_P = 0x50,
    KEY_Q = 0x51,
    KEY_R = 0x52,
    KEY_S = 0x53,
    KEY_T = 0x54,
    KEY_U = 0x55,
    KEY_V = 0x56,
    KEY_W = 0x57,
    KEY_X = 0x58,
    KEY_Y = 0x59,
    KEY_Z = 0x5A,

    KEY_LWIN = 0x5B,
    KEY_RWIN = 0x5C,
    KEY_APPS = 0x5D,

    KEY_SLEEP = 0x5F,

    KEY_NUMPAD0 = 0x60,
    KEY_NUMPAD1 = 0x61,
    KEY_NUMPAD2 = 0x62,
    KEY_NUMPAD3 = 0x63,
    KEY_NUMPAD4 = 0x64,
    KEY_NUMPAD5 = 0x65,
    KEY_NUMPAD6 = 0x66,
    KEY_NUMPAD7 = 0x67,
    KEY_NUMPAD8 = 0x68,
    KEY_NUMPAD9 = 0x69,
    KEY_MULTIPLY = 0x6A,
    KEY_ADD = 0x6B,
    KEY_SEPARATOR = 0x6C,
    KEY_SUBTRACT = 0x6D,
    KEY_DECIMAL = 0x6E,
    KEY_DIVIDE = 0x6F,
    KEY_F1 = 0x70,
    KEY_F2 = 0x71,
    KEY_F3 = 0x72,
    KEY_F4 = 0x73,
    KEY_F5 = 0x74,
    KEY_F6 = 0x75,
    KEY_F7 = 0x76,
    KEY_F8 = 0x77,
    KEY_F9 = 0x78,
    KEY_F10 = 0x79,
    KEY_F11 = 0x7A,
    KEY_F12 = 0x7B,
    KEY_F13 = 0x7C,
    KEY_F14 = 0x7D,
    KEY_F15 = 0x7E,
    KEY_F16 = 0x7F,
    KEY_F17 = 0x80,
    KEY_F18 = 0x81,
    KEY_F19 = 0x82,
    KEY_F20 = 0x83,
    KEY_F21 = 0x84,
    KEY_F22 = 0x85,
    KEY_F23 = 0x86,
    KEY_F24 = 0x87,

    KEY_NUMLOCK = 0x90,
    KEY_SCROLL = 0x91,

    KEY_NUMPAD_EQUAL = 0x92,

    KEY_LSHIFT = 0xA0,
    KEY_RSHIFT = 0xA1,
    KEY_LCONTROL = 0xA2,
    KEY_RCONTROL = 0xA3,
    KEY_LMENU = 0xA4,
    KEY_RMENU = 0xA5,

    KEY_SEMICOLON = 0xBA,
    KEY_PLUS = 0xBB,
    KEY_COMMA = 0xBC,
    KEY_MINUS = 0xBD,
    KEY_PERIOD = 0xBE,
    KEY_SLASH = 0xBF,
    KEY_GRAVE = 0xC0,
}

keyboard_state :: struct {
	keys: [256]bool,
}

mouse_state :: struct {
	x, y: i16,
	buttons: [BUTTON_MAX_BUTTONS]bool,
}

input_state :: struct {
	keyboard_current: keyboard_state,
	keyboard_previous: keyboard_state,
	mouse_current: mouse_state,
	mouse_previous: mouse_state,
}

input_initialized: bool = false
inpt_state : input_state = {}

input_initialize :: proc() {
	kzero_memory(&state, size_of(input_state))
	input_initialized = true
	l.log_info("Input subsystem initialized.")
}

input_shutdown :: proc() {
	input_initialized = false
	// kfree(inpt_state, size_of(inpt_state))
}

input_update :: proc(delta_time: f64) {
	if !input_initialized {
		return
	}

	kcopy_memory(&inpt_state.keyboard_previous, &inpt_state.keyboard_current, size_of(keyboard_state))
	kcopy_memory(&inpt_state.mouse_previous, &inpt_state.mouse_current, size_of(mouse_state))
}

input_process_key :: proc(key: keys, pressed: bool) {
	// Only handle this if the state actually changed.
	if inpt_state.keyboard_current.keys[key] != pressed {
		// Update internal state.
		inpt_state.keyboard_current.keys[key] = pressed

		input_context : event_context 
		data := input_context.data.([2]u16)
		data[0] = cast(u16)key

		event_fire(pressed ? cast(u16)system_event_code.EVENT_CODE_KEY_PRESSED : cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED, nil, input_context)
	}
}

input_process_button :: proc(button: buttons, pressed: bool) {
	// If the state changed, fire the event.

	if inpt_state.mouse_current.buttons[button] != pressed {
    	inpt_state.mouse_current.buttons[button] = pressed

		// Fire the event.
		input_context: event_context
		data := input_context.data.([2]u16)
		data[0] = cast(u16)button
		event_fire(pressed ? cast(u16)system_event_code.EVENT_CODE_BUTTON_PRESSED: cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED, nil, input_context)
	}
}

input_process_mouse_move :: proc(x, y: i16) {
	// Only process if actually different

	if inpt_state.mouse_current.x != x || inpt_state.mouse_current.y != y {
		// Update internal state
		inpt_state.mouse_current.x = x
		inpt_state.mouse_current.y = y

		input_context : event_context
		data := input_context.data.([2]u16)
		data[0] = cast(u16)x
		data[1] = cast(u16)y
		event_fire(cast(u16)system_event_code.EVENT_CODE_MOUSE_MOVED, nil, input_context)
	}
}

input_process_mouse_wheel :: proc(z_delta: i8) {
	// NOTE: no internal state to update.

	// Fire the event.
	input_context: event_context
	data := input_context.data.([2]u8)
	data[0] = cast(u8)z_delta
}

input_is_key_down :: proc(key: keys) -> bool {
	if !input_initialized {
		return false
	}

	return inpt_state.keyboard_current.keys[key] == true
}

input_is_key_up :: proc(key: keys) -> bool {
	if !input_initialized {
		return true
	}

	return inpt_state.keyboard_current.keys[key] == false
}


input_was_key_down :: proc(key: keys) -> bool {
	if !input_initialized {
		return false
	}

	return inpt_state.keyboard_previous.keys[key] == true
}

input_was_key_up :: proc(key: keys) -> bool {
	if !input_initialized {
		return true
	}

	return inpt_state.keyboard_previous.keys[key] == false
}

// mouse input

input_is_button_down :: proc(button: buttons) -> bool {
	if !input_initialized {
		return false
	}

	return inpt_state.mouse_current.buttons[button] == true
}

input_is_button_up :: proc(button: buttons) -> bool {
	if !input_initialized {
		return true
	}

	return inpt_state.mouse_current.buttons[button] == false
}

input_was_button_down :: proc(button: buttons) -> bool {
	if !input_initialized {
		return false
	}

	return inpt_state.mouse_previous.buttons[button] == true
}

input_was_button_up :: proc(button: buttons) -> bool {
	if !input_initialized {
		return true
	}

	return inpt_state.mouse_previous.buttons[button] == false
}

input_get_mouse_position :: proc(x, y: ^i32) {
	if !input_initialized {
		x^ = 0
		y^ = 0
		return
	}

	x^ = cast(i32)inpt_state.mouse_current.x
	y^ = cast(i32)inpt_state.mouse_current.y
}

input_get_previous_mouse_position :: proc(x, y: ^i32) {
	if !input_initialized {
		x^ = 0
		y^ = 0
		return
	}

	x^ = cast(i32)inpt_state.mouse_previous.x
	y^ = cast(i32)inpt_state.mouse_previous.y
}
