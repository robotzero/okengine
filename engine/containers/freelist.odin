package containers

import l "../logger"

FREELIST_INVALID :: max(u64)

@(private = "file")
freelist_node :: struct {
	offset: u64,
	size:   u64,
	next:   ^freelist_node,
}

// Tracks free ranges of an externally-owned buffer by offset.
// Callers get back u64 offsets, not pointers — the right shape for GPU
// buffer sub-allocation (vk.DeviceSize) and the dynamic_allocator below.
freelist :: struct {
	total_size:  u64,
	max_entries: u64,
	head:        ^freelist_node,
	nodes:       []freelist_node,
}

// Number of freelist_node slots needed to track a buffer of `total_size` bytes.
freelist_node_count :: proc(total_size: u64) -> u64 {
	return total_size / size_of(rawptr)
}

// Initialises the freelist over `nodes_storage`.
// Allocate the slice with: make([]freelist_node, freelist_node_count(total_size))
freelist_create :: proc(total_size: u64, nodes_storage: []freelist_node, out_list: ^freelist) {
	out_list.total_size = total_size
	out_list.max_entries = u64(len(nodes_storage))
	out_list.nodes = nodes_storage

	min_sensible := u64(size_of(freelist_node)) * 8
	if total_size < min_sensible {
		l.log_warning(
			"freelist_create: tracking %d bytes with a freelist is wasteful (min recommended: %d).",
			total_size,
			min_sensible,
		)
	}

	for i in 0 ..< out_list.max_entries {
		out_list.nodes[i].offset = FREELIST_INVALID
		out_list.nodes[i].size = FREELIST_INVALID
		out_list.nodes[i].next = nil
	}

	out_list.head = &out_list.nodes[0]
	out_list.head.offset = 0
	out_list.head.size = total_size
	out_list.head.next = nil
}

freelist_destroy :: proc(list: ^freelist) {
	if list == nil {
		return
	}
	for i in 0 ..< list.max_entries {
		list.nodes[i].offset = FREELIST_INVALID
		list.nodes[i].size = FREELIST_INVALID
		list.nodes[i].next = nil
	}
	list.head = nil
	list.total_size = 0
	list.max_entries = 0
}

// Find a free block of `size` bytes and write its offset into `out_offset`.
freelist_allocate_block :: proc(list: ^freelist, size: u64, out_offset: ^u64) -> bool {
	if list == nil || out_offset == nil || list.head == nil {
		return false
	}

	node := list.head
	previous: ^freelist_node = nil

	for node != nil {
		if node.size == size {
			out_offset^ = node.offset
			if previous != nil {
				previous.next = node.next
			} else {
				list.head = node.next
			}
			freelist_return_node(list, node)
			return true
		} else if node.size > size {
			out_offset^ = node.offset
			node.offset += size
			node.size -= size
			return true
		}
		previous = node
		node = node.next
	}

	l.log_warning(
		"freelist_allocate_block: no block large enough for %d bytes (free: %d).",
		size,
		freelist_free_space(list),
	)
	return false
}

// Return `size` bytes at `offset` to the freelist, coalescing adjacent ranges.
freelist_free_block :: proc(list: ^freelist, size: u64, offset: u64) -> bool {
	if list == nil || size == 0 {
		return false
	}

	// Head is nil when the entire buffer is allocated (exact-fit consumed the last node).
	// Restore it as a fresh head node covering the returned range.
	if list.head == nil {
		new_node := freelist_get_node(list)
		if new_node == nil {
			l.log_error("freelist_free_block: no free node slots available.")
			return false
		}
		new_node.offset = offset
		new_node.size = size
		new_node.next = nil
		list.head = new_node
		return true
	}

	node := list.head
	previous: ^freelist_node = nil

	for node != nil {
		if node.offset == offset {
			node.size += size
			if node.next != nil && node.next.offset == node.offset + node.size {
				node.size += node.next.size
				rubbish := node.next
				node.next = rubbish.next
				freelist_return_node(list, rubbish)
			}
			return true
		} else if node.offset > offset {
			new_node := freelist_get_node(list)
			if new_node == nil {
				l.log_error("freelist_free_block: no free node slots available.")
				return false
			}
			new_node.offset = offset
			new_node.size = size

			if previous != nil {
				previous.next = new_node
			} else {
				list.head = new_node
			}
			new_node.next = node

			// Coalesce forward.
			if new_node.next != nil &&
			   new_node.offset + new_node.size == new_node.next.offset {
				new_node.size += new_node.next.size
				rubbish := new_node.next
				new_node.next = rubbish.next
				freelist_return_node(list, rubbish)
			}

			// Coalesce backward.
			if previous != nil &&
			   previous.offset + previous.size == new_node.offset {
				previous.size += new_node.size
				rubbish := new_node
				previous.next = rubbish.next
				freelist_return_node(list, rubbish)
			}

			return true
		}

		previous = node
		node = node.next
	}

	l.log_warning("freelist_free_block: could not find block at offset %d. Possible corruption.", offset)
	return false
}

// Reset to fully-free without reallocating the node storage.
freelist_clear :: proc(list: ^freelist) {
	if list == nil {
		return
	}
	for i in 1 ..< list.max_entries {
		list.nodes[i].offset = FREELIST_INVALID
		list.nodes[i].size = FREELIST_INVALID
		list.nodes[i].next = nil
	}
	list.head = &list.nodes[0]
	list.head.offset = 0
	list.head.size = list.total_size
	list.head.next = nil
}

// Sum of all free ranges. O(n) — use sparingly.
freelist_free_space :: proc(list: ^freelist) -> u64 {
	if list == nil {
		return 0
	}
	total: u64 = 0
	node := list.head
	for node != nil {
		total += node.size
		node = node.next
	}
	return total
}

// ── internal helpers ─────────────────────────────────────────────────────────

@(private = "file")
freelist_get_node :: proc(list: ^freelist) -> ^freelist_node {
	for i in u64(1) ..< list.max_entries {
		if list.nodes[i].offset == FREELIST_INVALID {
			return &list.nodes[i]
		}
	}
	return nil
}

@(private = "file")
freelist_return_node :: proc(list: ^freelist, node: ^freelist_node) {
	node.offset = FREELIST_INVALID
	node.size = FREELIST_INVALID
	node.next = nil
}
