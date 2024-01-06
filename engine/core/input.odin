package core

import idef "input"

keyboard_state :: struct {
	keys: [256]bool,
}

mouse_state :: struct {
	x, y: i16,
	buttons: [idef.BUTTON_MAX_BUTTONS]bool,
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
	log_info("Input subsystem initialized.")
}

input_shutdown :: proc() {
	input_initialized = false
	// kfree(&inpt_state, size_of(inpt_state), .MEMORY_TAG_UNKNOWN)
}

input_update :: proc(delta_time: f64) {
	if !input_initialized {
		return
	}

	kcopy_memory(&inpt_state.keyboard_previous, &inpt_state.keyboard_current, size_of(keyboard_state))
	kcopy_memory(&inpt_state.mouse_previous, &inpt_state.mouse_current, size_of(mouse_state))
}

input_process_key :: proc(key: idef.keys, pressed: bool) {
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

input_process_button :: proc(button: idef.buttons, pressed: bool) {
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

input_is_key_down :: proc(key: idef.keys) -> bool {
	if !input_initialized {
		return false
	}

	return inpt_state.keyboard_current.keys[key] == true
}

input_is_key_up :: proc(key: idef.keys) -> bool {
	if !input_initialized {
		return true
	}

	return inpt_state.keyboard_current.keys[key] == false
}


input_was_key_down :: proc(key: idef.keys) -> bool {
	if !input_initialized {
		return false
	}

	return inpt_state.keyboard_previous.keys[key] == true
}

input_was_key_up :: proc(key: idef.keys) -> bool {
	if !input_initialized {
		return true
	}

	return inpt_state.keyboard_previous.keys[key] == false
}

// mouse input

input_is_button_down :: proc(button: idef.buttons) -> bool {
	if !input_initialized {
		return false
	}

	return inpt_state.mouse_current.buttons[button] == true
}

input_is_button_up :: proc(button: idef.buttons) -> bool {
	if !input_initialized {
		return true
	}

	return inpt_state.mouse_current.buttons[button] == false
}

input_was_button_down :: proc(button: idef.buttons) -> bool {
	if !input_initialized {
		return false
	}

	return inpt_state.mouse_previous.buttons[button] == true
}

input_was_button_up :: proc(button: idef.buttons) -> bool {
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
