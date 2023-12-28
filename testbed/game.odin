package testbed

import l "../engine/core/logger"

game_state :: struct {
	delta_time: f32,
}

game_initialize :: proc(game_inst: ^game) -> bool {
	l.log_debug("game initialize called")
	return true
}

game_update :: proc(game_inst: ^game, delta_time: f32) -> bool {
	return true
}

game_render :: proc(game_inst: ^game, delta_time: f32) -> bool {
	return true
}

game_on_resize :: proc(game_inst: ^game, width: u32, height: u32) {
	
}

