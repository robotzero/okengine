package platform

import "core:io"
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

read_line_into :: proc(r: io.Reader, buf: []u8) -> (n: int, ok: bool, err: io.Error) {
	if len(buf) == 0 {
		return 0, false, io.Error.Invalid_Argument
	}

	for i := 0; i < len(buf); i += 1 {
		b, e := io.read_byte(r)
		if e != nil {
			if e == io.Error.EOF && i > 0 {
				return i, true, nil
			}
			return i, false, e
		}
		buf[i] = b
		if b == '\n' {
			return i + 1, true, nil
		}
	}

	return len(buf), true, nil
}

filesystem_read_line :: proc(handle: os.Handle, buf: []u8, out_line_length: ^u64) -> b8 {
	if handle == 0 || out_line_length == nil {
		return false
	}
	r := os.stream_from_handle(handle)
	n, ok, _ := read_line_into(r, buf)
	if !ok {
		return false
	}
	out_line_length^ = u64(n)
	return true
}

