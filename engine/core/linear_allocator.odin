package core

import "mem:arena/virtual"

linear_allocator_create :: proc(total_size: uint, arena: ^Arena) {
	using virtual
	err := arena_init_static(arena, total_size); if err {
		panic("AAAAAAAAAAAA")
	}
}

linear_allocator_destroy :: proc(arena: ^Arena) {
	mem.free_all(arena)
}

linear_allocator_free_all :: proc(arena: ^Arena) {
	mem.free_all(arena)
}
