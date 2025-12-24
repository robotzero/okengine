package testbed

import c "engine:core"

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
	return true
}

game_update :: proc(game_inst: ^c.game, delta_time: f32) -> bool {
	return true
}

game_render :: proc(game_inst: ^c.game, delta_time: f32) -> bool {
	return true
}

game_on_resize :: proc(game_inst: ^c.game, width: i32, height: i32) {

}

