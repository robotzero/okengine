package core

import idef "input"

keyboard_state :: struct {
	keys: [256]bool,
}

mouse_state :: struct {
	x, y:    i16,
	buttons: [idef.buttons.BUTTON_MAX_BUTTONS]bool,
}

input_system_state :: struct {
	keyboard_current:  keyboard_state,
	keyboard_previous: keyboard_state,
	mouse_current:     mouse_state,
	mouse_previous:    mouse_state,
}

@(private = "file")
state_ptr: ^input_system_state

input_system_initialize :: proc(state: ^input_system_state) {
	kzero_memory(state, size_of(input_system_state))
	state_ptr = state
	log_info("Input subsystem initialized.")
}

input_system_shutdown :: proc(state: ^input_system_state) {
	state_ptr = nil
	// kfree(&inpt_state, size_of(inpt_state), .MEMORY_TAG_UNKNOWN)
}

input_update :: proc(delta_time: f64) {
	if state_ptr == nil {
		return
	}

	kcopy_memory(
		&state_ptr.keyboard_previous,
		&state_ptr.keyboard_current,
		size_of(keyboard_state),
	)
	kcopy_memory(&state_ptr.mouse_previous, &state_ptr.mouse_current, size_of(mouse_state))
}

input_process_key :: proc(key: idef.keys, pressed: bool) {
	if key == idef.keys.KEY_LALT {
		log_info("Left alt pressed.")
	}
	if key == idef.keys.KEY_RALT {
		log_info("Right alt pressed.")
	}

	if key == idef.keys.KEY_LCONTROL {
		log_info("Left ctrl pressed")
	}
	if key == idef.keys.KEY_RCONTROL {
		log_info("Right ctrl pressed")
	}

	// Only handle this if the state actually changed.
	if state_ptr.keyboard_current.keys[key] != pressed {
		// Update internal state.
		state_ptr.keyboard_current.keys[key] = pressed

		input_context: event_context = {
			data = [2]u16{cast(u16)key, {}},
		}
		event_fire(
			pressed ? cast(u16)system_event_code.EVENT_CODE_KEY_PRESSED : cast(u16)system_event_code.EVENT_CODE_KEY_RELEASED,
			nil,
			input_context,
		)
	}
}

input_process_button :: proc(button: idef.buttons, pressed: bool) {
	// If the state changed, fire the event.

	if state_ptr.mouse_current.buttons[button] != pressed {
		state_ptr.mouse_current.buttons[button] = pressed

		// Fire the event.
		input_context: event_context = {
			data = [2]u16{cast(u16)button, {}},
		}
		event_fire(
			pressed ? cast(u16)system_event_code.EVENT_CODE_BUTTON_PRESSED : cast(u16)system_event_code.EVENT_CODE_BUTTON_RELEASED,
			nil,
			input_context,
		)
	}
}

input_process_mouse_move :: proc(x, y: i16) {
	// Only process if actually different
	// log_debug("Mouse %i, %i", x, y)
	if state_ptr.mouse_current.x != x || state_ptr.mouse_current.y != y {
		// Update internal state
		state_ptr.mouse_current.x = x
		state_ptr.mouse_current.y = y

		input_context: event_context = {
			data = [2]u16{cast(u16)x, cast(u16)y},
		}
		event_fire(cast(u16)system_event_code.EVENT_CODE_MOUSE_MOVED, nil, input_context)
	}
}

input_process_mouse_wheel :: proc(z_delta: i8) {
	// NOTE: no internal state to update.

	// Fire the event.
	input_context: event_context = {
		data = [2]u8{cast(u8)z_delta, {}},
	}
}

input_is_key_down :: proc(key: idef.keys) -> bool {
	if state_ptr == nil {
		return false
	}

	return state_ptr.keyboard_current.keys[key] == true
}

input_is_key_up :: proc(key: idef.keys) -> bool {
	if state_ptr == nil {
		return true
	}

	return state_ptr.keyboard_current.keys[key] == false
}


input_was_key_down :: proc(key: idef.keys) -> bool {
	if state_ptr == nil {
		return false
	}

	return state_ptr.keyboard_previous.keys[key] == true
}

input_was_key_up :: proc(key: idef.keys) -> bool {
	if state_ptr == nil {
		return true
	}

	return state_ptr.keyboard_previous.keys[key] == false
}

// mouse input

input_is_button_down :: proc(button: idef.buttons) -> bool {
	if state_ptr == nil {
		return false
	}

	return state_ptr.mouse_current.buttons[button] == true
}

input_is_button_up :: proc(button: idef.buttons) -> bool {
	if state_ptr == nil {
		return true
	}

	return state_ptr.mouse_current.buttons[button] == false
}

input_was_button_down :: proc(button: idef.buttons) -> bool {
	if state_ptr == nil {
		return false
	}

	return state_ptr.mouse_previous.buttons[button] == true
}

input_was_button_up :: proc(button: idef.buttons) -> bool {
	if state_ptr == nil {
		return false
	}

	return state_ptr.mouse_previous.buttons[button] == false
}

input_get_mouse_position :: proc(x, y: ^i32) {
	if state_ptr == nil {
		x^ = 0
		y^ = 0
		return
	}

	x^ = cast(i32)state_ptr.mouse_current.x
	y^ = cast(i32)state_ptr.mouse_current.y
}

input_get_previous_mouse_position :: proc(x, y: ^i32) {
	if state_ptr == nil {
		x^ = 0
		y^ = 0
		return
	}

	x^ = cast(i32)state_ptr.mouse_previous.x
	y^ = cast(i32)state_ptr.mouse_previous.y
}

