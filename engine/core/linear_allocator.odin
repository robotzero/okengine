package core

import l "../logger"
import "core:mem"
import "core:mem/virtual"

linear_allocator :: struct {
	total_size:  u64,
	allocated:   u64,
	arena:       ^virtual.Arena,
	allocator:   mem.Allocator,
	owns_memory: bool,
}

linear_allocator_create :: proc(
	total_size: uint,
	out_allocator: ^linear_allocator,
) -> mem.Allocator {

	ensure(out_allocator != nil)

	arena: virtual.Arena
	out_allocator.total_size = cast(u64)total_size * mem.Megabyte
	out_allocator.allocated = 0
	out_allocator.owns_memory = true
	out_allocator.arena = &arena

	err := virtual.arena_init_static(
		&arena,
		reserved = total_size * mem.Megabyte,
		// commit_size = 16 * mem.Megabyte,
	)
	ensure(err == nil)
	allocator := virtual.arena_allocator(&arena)

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, allocator)
		out_allocator.allocator = mem.tracking_allocator(&track)
	} else {
		out_allocator.allocator = allocator
	}
	return allocator
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

linear_allocator_allocate :: proc(
	linear_alloc: ^linear_allocator,
	$T: typeid,
	sys_alloc: ^mem.Allocator,
) -> (
	^T,
	mem.Allocator_Error,
) {
	if linear_alloc == nil {
		return nil, nil
	}

	// @TODO force to handle this error and log only in debug mode, otherwise return error code
	if linear_alloc.allocated + size_of(T) > linear_alloc.total_size * mem.Megabyte {
		remaining := linear_alloc.total_size - linear_alloc.allocated
		l.log_error(
			"linear_allocator_allocate = Tried to allocate %v, only %v remaining",
			size_of(T),
			remaining,
		)
		return nil, mem.Allocator_Error.Out_Of_Memory
	}

	linear_alloc.allocated += size_of(T)
	// Allocate directly from the systems arena allocator, not via kallocate.
	obj, err := mem.new(T, sys_alloc^)
	return obj, err
}

