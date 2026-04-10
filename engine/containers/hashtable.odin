package containers

import "core:fmt"

hashtable :: struct($T: typeid) {
	entries:       map[string]T,
	default_value: T,
}

hashtable_create :: proc(
	element_size: u64,
	element_count: u32,
	is_pointer_type: bool,
	out_hashtable: ^hashtable($T),
	memory: []T,
	memory_ptr: []^T,
	allocator := context.allocator,
) {
	if out_hashtable == nil {
		fmt.println("ERROR hashtable create failed. No hashtable provided")
		return
	}
	if element_count == 0 || element_size == 0 {
		fmt.println("ERROR element_size and element_count must be a positive non-zero value.")
		return
	}

	out_hashtable.entries = make(map[string]T, int(element_count), allocator)
}

hashtable_destroy :: proc(table: ^hashtable($T), allocator := context.allocator) {
	if table != nil {
		delete(table.entries)
		table.entries = nil
	}
}

hashtable_set :: proc(table: ^hashtable($T), name: string, value: T) -> bool {
	if table == nil || name == "" {
		fmt.println("ERROR hashtable set requires table and name")
		return false
	}

	table.entries[name] = value
	return true
}

hashtable_get :: proc(table: ^hashtable($T), name: string, value: ^T) -> bool {
	if table == nil || name == "" || value == nil {
		fmt.println("ERROR hashtable get requires table, name and value")
		return false
	}

	entry, found := table.entries[name]
	if found {
		value^ = entry
	} else {
		value^ = table.default_value
	}
	return true
}

hashtable_fill :: proc(table: ^hashtable($T), value: T) -> bool {
	if table == nil {
		fmt.println("ERROR hashtable fill requires table")
		return false
	}

	table.default_value = value
	return true
}
