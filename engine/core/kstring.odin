package core

import "core:strings"

strings_equal :: proc(str0: string, str1: string) -> bool {
	result := strings.compare(str0, str1)
	return result == 0
}
