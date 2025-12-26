package platform

import "core:log"
import "core:os"

file_handle :: struct {
	handle:   os.Handle,
	is_valid: bool,
}

file_modes :: enum {
	FILE_MODE_READ  = os.O_RDONLY,
	FILE_MODE_WRITE = os.O_RDWR,
}

filesystem_open :: proc(path: string, mode: int) -> (os.Handle, bool) {
	handle, err := os.open(path, mode)
	if err != nil {
		log.errorf("AAAAAAAA %s", err)
		return 0, false
	}
	return handle, true
}

filesystem_exists :: proc(path: string) -> bool {
	fi, err := os.stat(path)
	defer os.file_info_slice_delete({fi})
	if err != nil {
		panic("NOOOO")
	}
	return true
}

filesystem_close :: proc(handle: os.Handle) {
	if handle != 0 {
		err := os.close(handle)
		if err != nil {
			panic("AAAAAAAAAAAAAAAAAAAA")
		}
	}
}

file_system_read_all_bytes :: proc(handle: os.Handle, allocator := context.allocator) -> []u8 {
	if handle != 0 {
		data, err := os.read_entire_file_from_handle_or_err(handle)
		if err != nil {
			delete(data)
			panic("AAAAAAAAAAAAAAAAAA")
		}
		return data
	}

	return {}
}

