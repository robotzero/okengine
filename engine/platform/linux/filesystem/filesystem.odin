package filesystem

import "core:io"
import "core:log"
import "core:os"

file_handle :: struct {
	handle:   ^os.File,
	is_valid: bool,
}

filesystem_open :: proc(path: string, flags := os.File_Flags{.Read}) -> (^os.File, bool) {
	handle, err := os.open(path, flags)
	if err != nil {
		log.errorf("AAAAAAAA %s", err)
		return nil, false
	}
	return handle, true
}

filesystem_exists :: proc(path: string, allocator := context.allocator) -> bool {
	fi, err := os.stat(path, allocator)
	defer os.file_info_slice_delete({fi}, allocator)
	if err != nil {
		return false
	}
	return true
}

filesystem_close :: proc(handle: ^os.File) {
	if handle != nil {
		err := os.close(handle)
		if err != nil {
			panic("AAAAAAAAAAAAAAAAAAAA")
		}
	}
}

file_system_read_all_bytes :: proc(handle: ^os.File, allocator := context.allocator) -> []u8 {
	if handle != nil {
		data, err := os.read_entire_file_from_file(handle, allocator)
		if err != nil {
			if data != nil {
				delete(data, allocator)
			}
			panic("AAAAAAAAAAAAAAAAAA")
		}
		return data
	}

	return {}
}

read_line_into :: proc(r: io.Reader, buf: []u8) -> (n: int, ok: bool, err: io.Error) {
	if len(buf) == 0 {
		return 0, false, io.Error.Buffer_Full
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

filesystem_read_line :: proc(handle: ^os.File, buf: []u8, out_line_length: ^u64) -> b8 {
	if handle == nil || out_line_length == nil {
		return false
	}
	r := os.to_stream(handle)
	n, ok, _ := read_line_into(r, buf)
	if !ok {
		return false
	}
	out_line_length^ = u64(n)
	return true
}

