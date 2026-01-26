package testbed

import idef "../engine/core/input"
import c "engine:core"
import "engine:okmath"

create_game :: proc(out_game: ^c.game) -> bool {
	out_game.app_config.name = "OK Engine Testbed"
	out_game.app_config.start_pos_x = 100
	out_game.app_config.start_pos_y = 100
	out_game.app_config.start_width = 1280
	out_game.app_config.start_height = 720
	out_game.update = game_update
	out_game.render = game_render
	out_game.initialize = game_initialize
	out_game.on_resize = game_on_resize
	out_game.state = c.kallocate(c.memory_tag.MEMORY_TAG_GAME, c.game_state)
	out_game.application_state = nil

	return true
}

game_initialize :: proc(game_inst: ^c.game) -> bool {
	c.log_debug("game initialize called")
	state := game_inst.state

	state.camera_position = okmath.vec3{0, 0, 30.0}
	state.camera_euler = okmath.vec3_zero()

	state.view = okmath.mat4_translation(state.camera_position)
	state.view = okmath.mat4_inverse(state.view)

	state.camera_view_dirty = true

	return true
}

game_update :: proc(game_inst: ^c.game, delta_time: f32) -> bool {

	if c.input_is_key_up(idef.keys.KEY_T) && c.input_is_key_down(idef.keys.KEY_T) {
		ev_context: c.event_context = {}
		c.event_fire(cast(u16)c.system_event_code.EVENT_CODE_DEBUG0, game_inst, ev_context)
	}
	state := game_inst.state
	if c.input_is_key_down(idef.keys.KEY_A) || c.input_is_key_down(idef.keys.KEY_LEFT) {
		camera_yaw(state, 1.0 * delta_time)

	}
	if c.input_is_key_down(idef.keys.KEY_D) || c.input_is_key_down(idef.keys.KEY_RIGHT) {
		camera_yaw(state, -1.0 * delta_time)

	}
	if c.input_is_key_down(idef.keys.KEY_UP) {
		camera_pitch(state, 1.0 * delta_time)
	}
	if c.input_is_key_down(idef.keys.KEY_DOWN) {
		camera_pitch(state, -1.0 * delta_time)
	}

	temp_move_speed := f32(50.0)
	velocity := okmath.vec3_zero()


	if c.input_is_key_down(idef.keys.KEY_W) {
		forward := okmath.mat4_forward(state.view)
		velocity = okmath.vec3_add(velocity, forward)
	}
	if c.input_is_key_down(idef.keys.KEY_S) {
		backward := okmath.mat4_backward(state.view)
		velocity = okmath.vec3_add(velocity, backward)
	}
	if c.input_is_key_down(idef.keys.KEY_Q) {
		left := okmath.mat4_left(state.view)
		velocity = okmath.vec3_add(velocity, left)
	}
	if c.input_is_key_down(idef.keys.KEY_E) {
		right := okmath.mat4_right(state.view)
		velocity = okmath.vec3_add(velocity, right)
	}
	if c.input_is_key_down(idef.keys.KEY_SPACE) {
		velocity.y = velocity.y + 1.0
	}
	if c.input_is_key_down(idef.keys.KEY_X) {
		velocity.y = velocity.y - 1.0
	}

	z := okmath.vec3_zero()

	if !okmath.vec3_compare(z, velocity, 0.0002) {
		okmath.vec3_normalize(&velocity)
		state.camera_position.x += velocity.x * temp_move_speed * delta_time
		state.camera_position.y += velocity.y * temp_move_speed * delta_time
		state.camera_position.z += velocity.z * temp_move_speed * delta_time
		state.camera_view_dirty = true
	}

	recalculate_view_matrix(state)

	c.renderer_set_view(state.view)
	return true
}

game_render :: proc(game_inst: ^c.game, delta_time: f32) -> bool {
	return true
}

game_on_resize :: proc(game_inst: ^c.game, width: i32, height: i32) {

}

recalculate_view_matrix :: proc(state: ^c.game_state) {
	if state.camera_view_dirty {
		rotation := okmath.mat4_euler_xyz(
			state.camera_euler.x,
			state.camera_euler.y,
			state.camera_euler.z,
		)
		translation := okmath.mat4_translation(state.camera_position)

		state.view = okmath.mat4_mul(rotation, translation)
		state.view = okmath.mat4_inverse(state.view)

		state.camera_view_dirty = false
	}
}

camera_yaw :: proc(state: ^c.game_state, amount: f32) {
	state.camera_euler.y += amount
	state.camera_view_dirty = true
}

camera_pitch :: proc(state: ^c.game_state, amount: f32) {
	state.camera_euler.x += amount

	// Clamp to avoid Gimbal lock.
	limit := okmath.deg_to_rad(89.0)
	state.camera_euler.x = clamp(state.camera_euler.x, -limit, limit)

	state.camera_view_dirty = true
}

