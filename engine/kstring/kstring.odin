package kstring

import "../okmath"
import "base:runtime"
import "core:strconv"
import "core:strings"

string_length :: proc(str: string) -> int {
	return len(str)
}

strings_eqali :: proc(str0, str1: string) -> bool {
	return strings.equal_fold(str0, str1)
}

strings_equal :: proc(str0: string, str1: string) -> bool {
	result := strings.compare(str0, str1)
	return result == 0
}

string_copy :: proc(source: string) -> string {
	cloned, _ := strings.clone(source)
	return cloned
}

string_ncopy :: proc(source: string, length: i64) -> string {
	if length <= 0 {
		return ""
	}
	n := int(length)
	if n > len(source) {
		n = len(source)
	}

	allocator := runtime.default_context().allocator
	cloned, _ := strings.clone(source[:n], allocator)
	return cloned
}

string_trim :: proc(source: string) -> string {
	trimmed := strings.trim_space(source)
	allocator := runtime.default_context().allocator
	cloned, _ := strings.clone(trimmed, allocator)
	return cloned
}

string_mid :: proc(source: string, start: i32, length: i32) -> string {
	start_local := start
	if len(source) == 0 {
		return ""
	}
	if start_local < 0 {
		start_local = 0
	}
	if start_local >= i32(len(source)) {
		return ""
	}

	start_i := int(start)
	if length == 0 {
		return ""
	}
	if length > 0 {
		end_i := start_i + int(length)
		if end_i > len(source) {
			end_i = len(source)
		}
		allocator := runtime.default_context().allocator
		cloned, _ := strings.clone(source[start_i:end_i], allocator)
		return cloned
	}

	allocator := runtime.default_context().allocator
	// Negative length means to the end.
	cloned, _ := strings.clone(source[start_i:], allocator)
	return cloned
}

string_index_of :: proc(source: string, c: u8) -> i32 {
	if len(source) == 0 {
		return -1
	}
	for i: int = 0; i < len(source); i += 1 {
		if source[i] == c {
			return i32(i)
		}
	}
	return -1
}

string_to_vec4 :: proc(source: string, out_vector: ^okmath.vec4) -> bool {
	if out_vector == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		return false
	}

	values: [4]f32
	for i in 0 ..< 4 {
		v, n, ok := strconv.parse_f32_prefix(s)
		if !ok {
			return false
		}
		values[i] = v
		if n >= len(s) {
			s = ""
		} else {
			s = strings.trim_space(s[n:])
		}
	}

	out_vector^ = okmath.vec4_create(values[0], values[1], values[2], values[3])
	return true
}

string_to_vec3 :: proc(source: string, out_vector: ^okmath.vec3) -> bool {
	if out_vector == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		return false
	}

	values: [3]f32
	for i in 0 ..< 3 {
		v, n, ok := strconv.parse_f32_prefix(s)
		if !ok {
			return false
		}
		values[i] = v
		if n >= len(s) {
			s = ""
		} else {
			s = strings.trim_space(s[n:])
		}
	}

	out_vector^ = okmath.vec3{values[0], values[1], values[2]}
	return true
}

string_to_vec2 :: proc(source: string, out_vector: ^okmath.vec2) -> bool {
	if out_vector == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		return false
	}

	values: [2]f32
	for i in 0 ..< 2 {
		v, n, ok := strconv.parse_f32_prefix(s)
		if !ok {
			return false
		}
		values[i] = v
		if n >= len(s) {
			s = ""
		} else {
			s = strings.trim_space(s[n:])
		}
	}

	out_vector^ = okmath.vec2{values[0], values[1]}
	return true
}

string_to_f32 :: proc(source: string, out_value: ^f32) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, _, ok := strconv.parse_f32_prefix(s)
	if !ok {
		out_value^ = 0
		return false
	}
	out_value^ = v
	return true
}

string_to_f64 :: proc(source: string, out_value: ^f64) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, _, ok := strconv.parse_f64_prefix(s)
	if !ok {
		out_value^ = 0
		return false
	}
	out_value^ = v
	return true
}

string_to_i8 :: proc(source: string, out_value: ^i8) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, ok := strconv.parse_i64_maybe_prefixed(s)
	if !ok || v < -128 || v > 127 {
		out_value^ = 0
		return false
	}
	out_value^ = i8(v)
	return true
}

string_to_i16 :: proc(source: string, out_value: ^i16) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, ok := strconv.parse_i64_maybe_prefixed(s)
	if !ok || v < -32768 || v > 32767 {
		out_value^ = 0
		return false
	}
	out_value^ = i16(v)
	return true
}

string_to_i32 :: proc(source: string, out_value: ^i32) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, ok := strconv.parse_i64_maybe_prefixed(s)
	if !ok || v < -2147483648 || v > 2147483647 {
		out_value^ = 0
		return false
	}
	out_value^ = i32(v)
	return true
}

string_to_i64 :: proc(source: string, out_value: ^i64) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, ok := strconv.parse_i64_maybe_prefixed(s)
	if !ok {
		out_value^ = 0
		return false
	}
	out_value^ = v
	return true
}

string_to_u8 :: proc(source: string, out_value: ^u8) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, ok := strconv.parse_u64_maybe_prefixed(s)
	if !ok || v > 255 {
		out_value^ = 0
		return false
	}
	out_value^ = u8(v)
	return true
}

string_to_u16 :: proc(source: string, out_value: ^u16) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, ok := strconv.parse_u64_maybe_prefixed(s)
	if !ok || v > 65535 {
		out_value^ = 0
		return false
	}
	out_value^ = u16(v)
	return true
}

string_to_u32 :: proc(source: string, out_value: ^u32) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, ok := strconv.parse_u64_maybe_prefixed(s)
	if !ok || v > 4294967295 {
		out_value^ = 0
		return false
	}
	out_value^ = u32(v)
	return true
}

string_to_u64 :: proc(source: string, out_value: ^u64) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = 0
		return false
	}
	v, ok := strconv.parse_u64_maybe_prefixed(s)
	if !ok {
		out_value^ = 0
		return false
	}
	out_value^ = v
	return true
}

string_to_bool :: proc(source: string, out_value: ^bool) -> bool {
	if out_value == nil {
		return false
	}
	s := strings.trim_space(source)
	if len(s) == 0 {
		out_value^ = false
		return false
	}
	out_value^ = strings_equal(s, "1") || strings_eqali(s, "true")
	return out_value^
}

