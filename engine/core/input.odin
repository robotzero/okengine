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
	BACKSPACE = 0x08,
    ENTER = 0x0D,
    TAB = 0x09,
    SHIFT = 0x10,
    CONTROL = 0x11,

    PAUSE = 0x13,
    CAPITAL = 0x14,

    ESCAPE = 0x1B,

    CONVERT = 0x1C,
    NONCONVERT = 0x1D,
    ACCEPT = 0x1E,
    MODECHANGE = 0x1F,

    SPACE = 0x20,
    PRIOR = 0x21,
    NEXT = 0x22,
    END = 0x23,
    HOME = 0x24,
    LEFT = 0x25,
    UP = 0x26,
    RIGHT = 0x27,
    DOWN = 0x28,
    SELECT = 0x29,
    PRINT = 0x2A,
    EXECUTE = 0x2B,
    SNAPSHOT = 0x2C,
    INSERT = 0x2D,
    DELETE = 0x2E,
    HELP = 0x2F,

    A = 0x41,
    B = 0x42,
    C = 0x43,
    D = 0x44,
    E = 0x45,
    F = 0x46,
    G = 0x47,
    H = 0x48,
    I = 0x49,
    J = 0x4A,
    K = 0x4B,
    L = 0x4C,
    M = 0x4D,
    N = 0x4E,
    O = 0x4F,
    P = 0x50,
    Q = 0x51,
    R = 0x52,
    S = 0x53,
    T = 0x54,
    U = 0x55,
    V = 0x56,
    W = 0x57,
    X = 0x58,
    Y = 0x59,
    Z = 0x5A,

    LWIN = 0x5B,
    RWIN = 0x5C,
    APPS = 0x5D,

    SLEEP = 0x5F,

    NUMPAD0 = 0x60,
    NUMPAD1 = 0x61,
    NUMPAD2 = 0x62,
    NUMPAD3 = 0x63,
    NUMPAD4 = 0x64,
    NUMPAD5 = 0x65,
    NUMPAD6 = 0x66,
    NUMPAD7 = 0x67,
    NUMPAD8 = 0x68,
    NUMPAD9 = 0x69,
    MULTIPLY = 0x6A,
    ADD = 0x6B,
    SEPARATOR = 0x6C,
    SUBTRACT = 0x6D,
    DECIMAL = 0x6E,
    DIVIDE = 0x6F,
    F1 = 0x70,
    F2 = 0x71,
    F3 = 0x72,
    F4 = 0x73,
    F5 = 0x74,
    F6 = 0x75,
    F7 = 0x76,
    F8 = 0x77,
    F9 = 0x78,
    F10 = 0x79,
    F11 = 0x7A,
    F12 = 0x7B,
    F13 = 0x7C,
    F14 = 0x7D,
    F15 = 0x7E,
    F16 = 0x7F,
    F17 = 0x80,
    F18 = 0x81,
    F19 = 0x82,
    F20 = 0x83,
    F21 = 0x84,
    F22 = 0x85,
    F23 = 0x86,
    F24 = 0x87,

    NUMLOCK = 0x90,
    SCROLL = 0x91,

    NUMPAD_EQUAL = 0x92,

    LSHIFT = 0xA0,
    RSHIFT = 0xA1,
    LCONTROL = 0xA2,
    RCONTROL = 0xA3,
    LMENU = 0xA4,
    RMENU = 0xA5,

    SEMICOLON = 0xBA,
    PLUS = 0xBB,
    COMMA = 0xBC,
    MINUS = 0xBD,
    PERIOD = 0xBE,
    SLASH = 0xBF,
    GRAVE = 0xC0,
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
