package containers

import "core:fmt"

DARRAY_DEFAULT_CAPACITY :: 1
DARRAY_RESIZE_FACTOR :: 2

DARRAY :: enum {
	CAPACITY,
	LENGTH,
	STRIDE,
	FIELD_LENGTH,
}

darray_create :: proc(capacity: u64, $T: typeid) -> [dynamic]T {
	return make([dynamic]T, capacity, capacity)
}
//@TODO use polymorphism there
darray_create_default :: proc($T: typeid) -> [dynamic]T {
	return make([dynamic]T, 0, DARRAY_DEFAULT_CAPACITY)
}

darray_destroy :: proc(arr: [dynamic]$T) {
	delete(arr)
}

darray_length :: proc(arr: [dynamic]$T) -> int {
	return darray_field_get(.LENGTH, arr)
}

darray_field_get :: proc(field: DARRAY, arr: [dynamic]$T) -> int {
	x: int = 0
	#partial switch field {
		case .CAPACITY: x = cap(arr)
		case .LENGTH: x = len(arr)
		case .STRIDE: x = size_of(T)
	}

	return x
}

darray_resize :: proc(arr: ^[dynamic]$T) {
	current_capacity:= cap(arr)
	reserve(arr, DARRAY_RESIZE_FACTOR * current_capacity)
}

darray_push :: proc(arr: ^[dynamic]$T, value: T) {
	append(arr, value)
}

darray_pop :: proc(arr: ^[dynamic]$T) {
	pop(arr)
}

darray_pop_at :: proc(arr: ^[dynamic]$T, index: int) {
	ordered_remove(arr, index)
}

darray_insert_at :: proc(arr: ^[dynamic]$T, index: int, value: T) {
	inject_at(arr, index, value)
}

