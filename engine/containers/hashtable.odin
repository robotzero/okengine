package containers

import "core:fmt"
import "core:hash"

// @TODO privacy to file
hashtable :: struct {
	element_size:    u64,
	element_count:   u32,
	is_pointer_type: bool,
	memory:          map[string]typeid,
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
	memory: map[string]$T,
) {
	if out_hashtable == nil {
		fmt.println("ERROR hashtable create failed. No hashtable provided")
	}
	if element_count == 0 || element_size == 0 {
		fmt.println("ERROR element_size and element_count must be a positive non-zero value.")
	}

	out_hashtable.element_count = element_count
	out_hashtable.element_size = element_size
	out_hashtable.memory = memory
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
	}
}

//@TODO use conditional parapoly for $T, so that only specific types can be set in hashtable
hashtable_set :: proc(table: ^hashtable, name: string, $T: typeid) -> bool {
	if table == nil || name == "" || value == nil {
		fmt.println("ERROR hashtable set requires table name and value")
		return false
	}

	if table.is_pointer_type {
		fmt.println("ERROR aaa")
		return false
	}

	hash := hash_name(name, table.element_count)
	table.memory[name] = T
	return true
}

hashtable_get :: proc(table: ^hashtable, name: string) -> (^$T, bool) {

	if table == nil || name == "" || value == nil {
		fmt.println("ERROR hashtable set requires table name and value")
		return nil, false
	}

	if table.is_pointer_type {
		fmt.println("ERROR aaa")
		return nil, false
	}

	hash_name(name, table.element_count)
	return table.memory[name], true
}

