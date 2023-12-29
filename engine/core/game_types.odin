package core

game :: struct {
	app_config: application_config,
	initialize : #type proc(game_inst: ^game) -> bool,
	update : #type proc(game_inst: ^game, delta_time: f32) -> bool,
	render : #type proc(game_inst: ^game, delta_time: f32) -> bool,
	on_resize : #type proc(game_inst: ^game, width: i32, height: i32),
	state: rawptr,
}
