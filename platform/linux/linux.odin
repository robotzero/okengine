// @TODO switch to file tags and not build tags
//+build linux
package platform

import xlib "vendor:x11/xlib"
import "core:sys/unix"
import "core:path/filepath"
import "core:fmt"
foreign import X11xcb "system:X11-xcb"
// foreign import xcb "system:libxcb.so"
foreign import xcb "system:xcb"
foreign import xlib2 "system:X11"

// internal_state :: struct {
// 	// display : ^xlib.Display,
// 	connection: ^xcb.xcb_connection_t,
// }

_xcb_xid :: struct {
	lock: unix.pthread_mutex_t,
	last: i32,
	base: i32,
	max: i32,
	inc: i32,
}

xcb_keycode_t:: distinct u8

xcb_setup_t :: struct {
	status: u8,
	pad0: u8,
	protocol_major_version: u16,
 	protocol_minor_version: u16,
    length: u16,
	release_number: u32,
	resource_id_base: u32,
	resource_id_mask: u32,
	motion_buffer_size: u32,
	vendor_len: u16,
	maximum_request_length: u16,
	roots_len: u8,
	pixmap_formats_len: u8,
	image_byte_order: u8,
	bitmap_format_bit_order: u8,
	bitmap_format_scanline_unit: u8,
	bitmap_format_scanline_pad: u8,
	min_keycode: xcb_keycode_t,
	max_keycode: xcb_keycode_t,
    pad1: [4]u8,
}

node :: struct {
	next: ^node,
	key: u32,
	data: rawptr,
}

_xcb_map :: struct {
	head: ^node,
	tail: ^^node,
}

reply_list :: struct {
	reply: rawptr,
	next: ^reply_list,
}

xcb_generic_event_t :: struct {
	response_type: u8,
	pad0: u8,
	sequence: u16,
	pad: [7]u32,
	full_sequence: u32,
}

event_list :: struct {
	event: ^xcb_generic_event_t,
	next: ^event_list,
}

reader_list :: struct {
	request: u64,
	data: ^unix.pthread_cond_t,
	next: ^reader_list,
}

xcb_special_event :: struct {
	next: ^xcb_special_event,
	extension: u8,
	eid: u32,
	stamp: ^u32,
	events: ^event_list,
	events_tail: ^^event_list,
	special_event_cond: unix.pthread_cond_t,
}

special_list :: struct {
	se: ^xcb_special_event,
	next: ^special_list,
}

Workarounds :: enum {
   WORKAROUND_NONE,
   WORKAROUND_GLX_GET_FB_CONFIGS_BUG,
   WORKAROUND_EXTERNAL_SOCKET_OWNER,
}

Lazy_reply_tag :: enum {
	LAZY_NONE = 0,
	LAZY_COOKIE,
	LAZY_FORCED,
}

xcb_big_requests_enable_cookie_t :: struct {
	sequence: u32,
}

Blah :: union {
	xcb_big_requests_enable_cookie_t,
	u32,
}

pending_reply :: struct {
	first_request: u64,
	last_request: u64,
	workaround: Workarounds,
	flags: i32,
	next: ^pending_reply,
}

_xcb_in :: struct {
	event_cond: unix.pthread_cond_t,
	reading: i32,
	queue: [4096]b8,
	request_expected: u64,
	request_read: u64,
	request_completed: u64,
	current_reply: ^reply_list,
	current_reply_tail: ^^reply_list, 
	replies: ^_xcb_map,
	events: ^event_list,
	events_tail: ^^event_list,
	readers: ^reader_list,
	special_waiters: ^special_list,
	pending_replies: ^pending_reply,
	pending_replies_tail: ^^pending_reply,
	special_events: ^xcb_special_event,
}

_xcb_out :: struct {
	cond: unix.pthread_cond_t,
	writing: i32,
	socket_cond: unix.pthread_cond_t,
	return_socket: proc "c" (closure: rawptr),
	socket_clousure: rawptr,
	queue: [16384]b8,
	queue_len: i32,
	request: u64,
	request_written: u64,
	reqlenlock: unix.pthread_mutex_t,
	maximum_request_length_tag: Lazy_reply_tag,
	maximum_request_length: Blah,
}

xcb_connection_t :: struct {
	has_error: i32,
	setup: ^xcb_setup_t,
	fd: i32,
	iolock: unix.pthread_mutex_t,
	in_: _xcb_in,
	out: _xcb_out,
	// ext: _xcb_ext,
	// xid: _xcb_xid,
}

@(default_calling_convention="c")
foreign xcb {
	xcb_connection_has_error :: proc(^xcb_connection_t) -> i32 ---
	xcb_get_setup :: proc(^xcb_connection_t) -> ^xcb_setup_t ---
}

@(default_calling_convention="c")
foreign X11xcb {
	XGetXCBConnection :: proc(^xlib.Display) -> ^xcb_connection_t ---
}
platform_setup :: proc() {
	display: ^xlib.Display = xlib.XOpenDisplay(nil)
	xlib.XAutoRepeatOff(display)
	connection: ^xcb_connection_t = XGetXCBConnection(display)
	// @TODO use or_error
	if (xcb_connection_has_error(connection) == 1) {
		panic("")
	}

	setup : ^xcb_setup_t = xcb_get_setup(connection)
    
}
