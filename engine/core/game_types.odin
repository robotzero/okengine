package core

import "engine:okmath"

game_state :: struct {
	delta_time:        f32,
	view:              okmath.mat4,
	camera_position:   okmath.vec3,
	camera_euler:      okmath.vec3,
	camera_view_dirty: bool,
}

game :: struct {
	app_config:        application_config,
	initialize:        #type proc(game_inst: ^game) -> bool,
	update:            #type proc(game_inst: ^game, delta_time: f32) -> bool,
	render:            #type proc(game_inst: ^game, delta_time: f32) -> bool,
	on_resize:         #type proc(game_inst: ^game, width: i32, height: i32),
	state:             ^game_state,
	application_state: ^application_state,
}

