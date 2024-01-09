package core

clock :: struct {
	start_time: i64,
	elapsed: i64,
}

clock_update :: proc(c: ^clock) {
	if c.start_time != 0 {
		c.elapsed = platform_get_absolute_time() - c.start_time
	}
}

clock_start :: proc(c: ^clock) {
	c.start_time = platform_get_absolute_time()
	c.elapsed = 0
}

clock_stop :: proc(c: ^clock) {
	c.start_time = 0
}
