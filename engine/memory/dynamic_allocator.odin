package memory

import c "../containers"
import l "../logger"
import "core:mem"

// Minimum alignment enforced on every allocation. Must be a power of two.
// 16 bytes covers all SIMD types (vec4, mat4) on x86-64.
DYNAMIC_ALLOCATOR_ALIGNMENT :: 16

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
	// Allocate the memory block with SIMD-safe alignment so that offset-0
	// (and every subsequent DYNAMIC_ALLOCATOR_ALIGNMENT-aligned offset) is
	// suitable for mat4 / vec4 / SSE operands.
	raw, err := mem.alloc(int(total_size), DYNAMIC_ALLOCATOR_ALIGNMENT)
	if err != nil || raw == nil {
		l.log_error("dynamic_allocator_create: failed to allocate aligned memory block.")
		// freelist_create hasn't been called yet so list.nodes is unset;
		// delete freelist_data directly here.
		delete(out.freelist_data)
		out.freelist_data = nil
		return false
	}
	mem.set(raw, 0, int(total_size))
	out.memory_block = ([^]u8)(raw)[:total_size]

	c.freelist_create(total_size, out.freelist_data, &out.list)
	out.freelist_data = nil // ownership transferred to list.nodes; freelist_destroy will free it
	return true
}

dynamic_allocator_destroy :: proc(a: ^dynamic_allocator) {
	if a == nil {
		return
	}
	c.freelist_destroy(&a.list)
	mem.free(raw_data(a.memory_block))
	a.memory_block = nil
	a.total_size = 0
}

dynamic_allocator_allocate :: proc(a: ^dynamic_allocator, size: u64) -> []u8 {
	if a == nil || size == 0 {
		l.log_error("dynamic_allocator_allocate: requires valid allocator and size > 0.")
		return nil
	}
	// Round up to alignment so every returned pointer is SIMD-safe and
	// the next allocation also starts on an aligned boundary.
	aligned_size := (size + DYNAMIC_ALLOCATOR_ALIGNMENT - 1) & ~u64(DYNAMIC_ALLOCATOR_ALIGNMENT - 1)
	offset: u64
	if !c.freelist_allocate_block(&a.list, aligned_size, &offset) {
		l.log_error(
			"dynamic_allocator_allocate: no block large enough. Requested: %d, free: %d.",
			size,
			c.freelist_free_space(&a.list),
		)
		return nil
	}
	// Return the full aligned slice so that dynamic_allocator_free receives
	// the same length that was registered with the freelist.
	return a.memory_block[offset:offset + aligned_size]
}

// Returns true if the block was freed, false if the pointer is outside this
// allocator's range (e.g. a pre-init platform allocation that should be freed
// through the platform layer instead).
dynamic_allocator_free :: proc(a: ^dynamic_allocator, block: []u8) -> bool {
	if a == nil || block == nil || len(block) == 0 {
		l.log_error("dynamic_allocator_free: requires valid allocator and block.")
		return false
	}
	// Recover the offset from the pointer difference.
	block_start := uintptr(raw_data(block))
	mem_start := uintptr(raw_data(a.memory_block))
	mem_end := mem_start + uintptr(a.total_size)

	if block_start < mem_start || block_start >= mem_end {
		// Not our pointer — caller should fall back to platform free.
		return false
	}

	offset := u64(block_start - mem_start)
	if !c.freelist_free_block(&a.list, u64(len(block)), offset) {
		l.log_error("dynamic_allocator_free: freelist_free_block failed.")
		return false
	}
	return true
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
		// Reconstruct the slice using the aligned size to match what was registered
		// with the freelist in dynamic_allocator_allocate.
		aligned_old := (old_size + DYNAMIC_ALLOCATOR_ALIGNMENT - 1) &
			~int(DYNAMIC_ALLOCATOR_ALIGNMENT - 1)
		block := mem.byte_slice(old_memory, aligned_old)
		if !dynamic_allocator_free(a, block) {
			return nil, .Invalid_Pointer
		}
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
			aligned_old := (old_size + DYNAMIC_ALLOCATOR_ALIGNMENT - 1) &
				~int(DYNAMIC_ALLOCATOR_ALIGNMENT - 1)
			old_block := mem.byte_slice(old_memory, aligned_old)
			_ = dynamic_allocator_free(a, old_block)
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
