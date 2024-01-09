package core

renderer_backend_type :: enum {
	RENDERER_BACKEND_TYPE_VULKAN,
    RENDERER_BACKEND_TYPE_OPENGL,
    RENDERER_BACKEND_TYPE_DIRECTX,
}

renderer_initialize_proc :: #type proc(backend: ^renderer_backend, application_name: string, plat_state: ^renderer_platform_state) -> bool
renderer_shutdown_proc :: #type proc(backend: ^renderer_backend)
renderer_resized_proc :: #type proc (backend: ^renderer_backend, width: u16, height: u16)
renderer_begin_frame_proc :: #type proc(backend: ^renderer_backend, delta_time: f32) -> bool
renderer_end_frame_proc :: #type proc(backend: ^renderer_backend, delta_time: f32) -> bool

renderer_backend :: struct {
	plat_state: ^renderer_platform_state,
	frame_number: u64,
	initialize: renderer_initialize_proc,
	shutdown: renderer_shutdown_proc,
	resized: renderer_resized_proc,
	begin_frame: renderer_begin_frame_proc,
	end_frame: renderer_end_frame_proc,
}

render_packet :: struct {
	delta_time: f32,
}
