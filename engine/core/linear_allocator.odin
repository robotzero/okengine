package core

import "core:mem"
import "core:mem/virtual"

linear_allocator :: struct {
	total_size: u64,
	allocated: u64,
	arena: ^virtual.Arena,
	allocator: mem.Allocator,
	owns_memory: bool,
}

linear_allocator_create :: proc(total_size: uint, out_allocator: ^linear_allocator) {
	if out_allocator == nil {
		return
	}
	arena: virtual.Arena = {}
	out_allocator.total_size = cast(u64)total_size
	out_allocator.allocated = 0
	out_allocator.owns_memory = true
	out_allocator.arena = &arena

	err := virtual.arena_init_static(out_allocator.arena, total_size); if err != nil {
		panic("AAAAAAAAAAAA")
	}
	allocator := virtual.arena_allocator(out_allocator.arena)
	out_allocator.allocator = allocator
}

linear_allocator_destroy :: proc(allocator: ^linear_allocator) {
	if allocator == nil {
		return
	}
	allocator.allocated = 0
	allocator.total_size = 0
	
	virtual.arena_destroy(allocator.arena)
}

linear_allocator_free_all :: proc(allocator: ^linear_allocator) {
	if allocator == nil {
		return
	}
	allocator.allocated = 0
	mem.free_all(allocator.allocator)
}

linear_allocator_allocate :: proc(allocator: ^linear_allocator, size: u64) -> []byte {
	if allocator == nil {
		return nil
	}

	if allocator.allocated + size > allocator.total_size {
		remaining := allocator.total_size - allocator.allocated
		log_error("linear_allocator_allocate = Tried to allocate %v, only %v remaining", size, remaining)
		return nil
	}

	// data, err := virtual.arena_alloc(allocator.arena, cast(uint) size, 0); if err != nil {
	// 	panic("AAAAAAAAAAAAAAAAAAA2")
	// }

	allocator.allocated += size
	return nil
}
