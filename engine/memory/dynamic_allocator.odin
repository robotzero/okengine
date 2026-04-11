package memory

import c "../containers"
import l "../logger"
import "core:mem"

// A general-purpose dynamic allocator backed by a freelist.
// Owns a single contiguous block of memory and sub-allocates from it.
// Implements mem.Allocator so it integrates with Odin's context.allocator.
//
// Memory layout of the backing block:
//   [ freelist nodes | usable memory ]
//
// The freelist nodes live at the front; the usable region starts immediately
// after and is what callers actually get slices/pointers into.
dynamic_allocator :: struct {
	total_size:    u64,
	list:          c.freelist,
	freelist_data: []c.freelist_node, // backing storage for the freelist nodes
	memory_block:  []u8,             // the usable allocation region
}

dynamic_allocator_create :: proc(total_size: u64, out: ^dynamic_allocator) -> bool {
	if total_size < 1 {
		l.log_error("dynamic_allocator_create: total_size must be > 0.")
		return false
	}

	node_count := c.freelist_node_count(total_size)
	out.total_size = total_size
	out.freelist_data = make([]c.freelist_node, node_count)
	out.memory_block = make([]u8, total_size)

	c.freelist_create(total_size, out.freelist_data, &out.list)
	return true
}

dynamic_allocator_destroy :: proc(a: ^dynamic_allocator) {
	if a == nil {
		return
	}
	c.freelist_destroy(&a.list)
	delete(a.freelist_data)
	delete(a.memory_block)
	a.total_size = 0
}

dynamic_allocator_allocate :: proc(a: ^dynamic_allocator, size: u64) -> []u8 {
	if a == nil || size == 0 {
		l.log_error("dynamic_allocator_allocate: requires valid allocator and size > 0.")
		return nil
	}
	offset: u64
	if !c.freelist_allocate_block(&a.list, size, &offset) {
		l.log_error(
			"dynamic_allocator_allocate: no block large enough. Requested: %d, free: %d.",
			size,
			c.freelist_free_space(&a.list),
		)
		return nil
	}
	return a.memory_block[offset:offset + size]
}

dynamic_allocator_free :: proc(a: ^dynamic_allocator, block: []u8) {
	if a == nil || block == nil {
		l.log_error("dynamic_allocator_free: requires valid allocator and block.")
		return
	}
	// Recover the offset from the pointer difference.
	block_start := uintptr(raw_data(block))
	mem_start := uintptr(raw_data(a.memory_block))
	mem_end := mem_start + uintptr(a.total_size)

	if block_start < mem_start || block_start >= mem_end {
		l.log_error(
			"dynamic_allocator_free: block at 0x%x is outside allocator range [0x%x, 0x%x).",
			block_start,
			mem_start,
			mem_end,
		)
		return
	}

	offset := u64(block_start - mem_start)
	if !c.freelist_free_block(&a.list, u64(len(block)), offset) {
		l.log_error("dynamic_allocator_free: freelist_free_block failed.")
	}
}

dynamic_allocator_free_space :: proc(a: ^dynamic_allocator) -> u64 {
	return c.freelist_free_space(&a.list)
}

// ── mem.Allocator integration ─────────────────────────────────────────────────

// Returns a standard mem.Allocator backed by this dynamic_allocator.
// Usage: context.allocator = dynamic_allocator_to_odin_allocator(&my_alloc)
dynamic_allocator_to_odin_allocator :: proc(a: ^dynamic_allocator) -> mem.Allocator {
	return mem.Allocator{procedure = dynamic_allocator_proc, data = a}
}

@(private = "file")
dynamic_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	a := (^dynamic_allocator)(allocator_data)

	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		result := dynamic_allocator_allocate(a, u64(size))
		if result == nil {
			return nil, .Out_Of_Memory
		}
		if mode == .Alloc {
			mem.zero_slice(result)
		}
		return result, nil

	case .Free:
		if old_memory == nil {
			return nil, nil
		}
		// Reconstruct the slice from the raw pointer and old_size.
		block := mem.byte_slice(old_memory, old_size)
		dynamic_allocator_free(a, block)
		return nil, nil

	case .Free_All:
		c.freelist_clear(&a.list)
		return nil, nil

	case .Resize, .Resize_Non_Zeroed:
		// Allocate new, copy, free old.
		new_block := dynamic_allocator_allocate(a, u64(size))
		if new_block == nil {
			return nil, .Out_Of_Memory
		}
		if old_memory != nil && old_size > 0 {
			copy_amount := min(old_size, size)
			mem.copy(raw_data(new_block), old_memory, copy_amount)
			old_block := mem.byte_slice(old_memory, old_size)
			dynamic_allocator_free(a, old_block)
		}
		if mode == .Resize {
			// Zero the newly added region if growing.
			if size > old_size {
				mem.zero(raw_data(new_block[old_size:]), size - old_size)
			}
		}
		return new_block, nil

	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Free_All, .Resize, .Resize_Non_Zeroed, .Query_Features}
		}
		return nil, nil

	case .Query_Info:
		return nil, .Mode_Not_Implemented
	}

	return nil, .Mode_Not_Implemented
}
