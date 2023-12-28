package testbed

create_game::proc(out_game: ^game) -> bool {
	out_game.app_config.start_pos_x = 100
	out_game.app_config.start_pos_y = 100
	out_game.app_config.start_width = 1280
	out_game.app_config.start_height = 720
	out_game.update = game_update
	out_game.render = game_render
	out_game.initialize = game_initialize
	out_game.on_resize = game_on_resize

	out_game.state = platform_allocate(size_of(game_state), false)

	return true
}
