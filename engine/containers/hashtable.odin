package containers

import "core:fmt"
import "core:hash"

// @TODO privacy to file
hashtable :: struct($T: typeid) {
	element_size:    u64,
	element_count:   u32,
	is_pointer_type: bool,
	memory:          map[string]T,
	memory_ptr:      map[string]^T,
}

//@TODO configurable hash alghorithm
hash_name :: proc(name: string, element_count: u32) -> u64 {
	hash := hash.murmur64a(transmute([]u8)name)
	hash %= u64(element_count)

	return hash
}

hashtabe_create :: proc(
	element_size: u64,
	element_count: u32,
	is_pointer_type: bool,
	out_hashtable: ^hashtable,
	$T: typeid,
) {
	if out_hashtable == nil {
		fmt.println("ERROR hashtable create failed. No hashtable provided")
	}
	if element_count == 0 || element_size == 0 {
		fmt.println("ERROR element_size and element_count must be a positive non-zero value.")
	}

	out_hashtable.element_count = element_count
	out_hashtable.element_size = element_size
	if is_pointer_type {
		out_hashtable.memory_ptr = make(map[string]^T)
	} else {
		out_hashtable.memory = make(map[string]T)
	}

	out_hashtable.is_pointer_type = is_pointer_type

	// TODO kzeromemory
}

hashtable_destroy :: proc(table: ^hashtable) {
	if table != nil {
		table.element_count = 0
		table.element_size = 0
		table.is_pointer_type = false
		// @TODO check if this deletes stuff or just zeros it and leave the contents hanging
		clear(&table.memory)
		for key in table.memory {
			// free(table.memory[key])
		}
		delete(table.memory)
	}
}

//@TODO use conditional parapoly for $T, so that only specific types can be set in hashtable
hashtable_set :: proc(table: ^hashtable, name: string, value: $T) -> bool {
	if table == nil || name == "" || value == nil {
		fmt.println("ERROR hashtable set requires table name and value")
		return false
	}

	if table.is_pointer_type {
		fmt.println("ERROR aaa")
		return false
	}

	hash := hash_name(name, table.element_count)
	table.memory[name] = value
	return true
}

hashtable_get :: proc(table: ^hashtable, name: string, $T: typeid, value: ^T) -> bool {
	if table == nil || name == "" || value == nil {
		fmt.println("ERROR hashtable set requires table name and value")
		return nil, false
	}

	if table.is_pointer_type {
		fmt.println("ERROR aaa")
		return nil, false
	}

	hash_name(name, table.element_count)
	elem, ok := table.memory[name]
	if ok {
		value^ = elem
	} else {
		e := new(T)
		e.handle = INVALID_ID
		e.auto_release = false
		e.reference_count = 0
		value^ = e
	}
	return true
}

hashtable_fill :: proc(table: ^hashtable, $T: typeid) -> bool {
	if table == nil || value == nil {
		fmt.println("hashtable fill aaa")
		return false
	}

	if table.is_pointer_type {
		fmt.println("aaabc")
		return false
	}

	table.memory["default"] = new(T)
	return true
}

