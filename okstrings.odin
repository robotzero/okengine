package core

import "core:strings"

string_length :: proc(str: string) {
	return len(str)
}

strings_eqali :: proc(str0, str1: string) -> bool {
	return strings.equal_fold(str0, str1)
}

