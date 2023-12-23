// @TODO switch to file tags and not build tags
//+build linux
package platform

import xlib "vendor:x11/xlib"
import "core:sys/unix"
import "core:path/filepath"
import "core:fmt"
// import l "../engine/core/logger"
foreign import X11xcb "system:X11-xcb"
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

xcb_keycode_t :: distinct u8
xcb_window_t :: distinct uint
xcb_colormap_t :: distinct uint
xcb_visualid_t :: distinct uint
xcb_atom_t :: distinct rawptr

xcb_intern_atom_reply_t :: struct {
	response_type: u8,
	pad0: u8,
	sequence: u16,
	length: u32,
	atom: xcb_atom_t,
}

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
	next: [^]node,
	key: u32,
	data: rawptr,
}

_xcb_map :: struct {
	head: [^]node,
	tail: [^]^node,
}

reply_list :: struct {
	reply: rawptr,
	next: [^]reply_list,
}

xcb_generic_event_t :: struct {
	response_type: u8,
	pad0: u8,
	sequence: u16,
	pad: [7]u32,
	full_sequence: u32,
}

event_list :: struct {
	event: [^]xcb_generic_event_t,
	next: [^]event_list,
}

reader_list :: struct {
	request: u64,
	data: [^]unix.pthread_cond_t,
	next: [^]reader_list,
}

xcb_special_event :: struct {
	next: [^]xcb_special_event,
	extension: u8,
	eid: u32,
	stamp: ^u32,
	events: [^]event_list,
	events_tail: [^]^event_list,
	special_event_cond: unix.pthread_cond_t,
}

special_list :: struct {
	se: [^]xcb_special_event,
	next: [^]special_list,
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

xcb_cw_t :: enum u32 {
  XCB_CW_BACK_PIXMAP = 0, XCB_CW_BACK_PIXEL = 1, XCB_CW_BORDER_PIXMAP = 2, XCB_CW_BORDER_PIXEL = 3,
  XCB_CW_BIT_GRAVITY = 4, XCB_CW_WIN_GRAVITY = 5, XCB_CW_BACKING_STORE = 6, XCB_CW_BACKING_PLANES = 7,
  XCB_CW_BACKING_PIXEL = 8, XCB_CW_OVERRIDE_REDIRECT = 9, XCB_CW_SAVE_UNDER = 10, XCB_CW_EVENT_MASK = 11,
  XCB_CW_DONT_PROPAGATE = 12, XCB_CW_COLORMAP = 13, XCB_CW_CURSOR = 14,
}

mask :: bit_set[xcb_cw_t; u32]

xcb_event_mask_t :: enum u32 {
  XCB_EVENT_MASK_NO_EVENT = 0, XCB_EVENT_MASK_KEY_PRESS = 1, XCB_EVENT_MASK_KEY_RELEASE = 2, XCB_EVENT_MASK_BUTTON_PRESS = 3,
  XCB_EVENT_MASK_BUTTON_RELEASE = 3, XCB_EVENT_MASK_ENTER_WINDOW = 4, XCB_EVENT_MASK_LEAVE_WINDOW = 5, XCB_EVENT_MASK_POINTER_MOTION = 6,
  XCB_EVENT_MASK_POINTER_MOTION_HINT = 7, XCB_EVENT_MASK_BUTTON_1_MOTION = 8, XCB_EVENT_MASK_BUTTON_2_MOTION = 9, XCB_EVENT_MASK_BUTTON_3_MOTION = 10,
  XCB_EVENT_MASK_BUTTON_4_MOTION = 11, XCB_EVENT_MASK_BUTTON_5_MOTION = 12, XCB_EVENT_MASK_BUTTON_MOTION = 13, XCB_EVENT_MASK_KEYMAP_STATE = 14,
  XCB_EVENT_MASK_EXPOSURE = 16, XCB_EVENT_MASK_VISIBILITY_CHANGE = 17, XCB_EVENT_MASK_STRUCTURE_NOTIFY = 18, XCB_EVENT_MASK_RESIZE_REDIRECT = 19,
  XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY = 20, XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT = 21, XCB_EVENT_MASK_FOCUS_CHANGE = 22, XCB_EVENT_MASK_PROPERTY_CHANGE = 23,
  XCB_EVENT_MASK_COLOR_MAP_CHANGE = 24, XCB_EVENT_MASK_OWNER_GRAB_BUTTON = 25,
}

mask2 :: bit_set[xcb_event_mask_t; u32]

xcb_big_requests_enable_cookie_t :: struct {
	sequence: u32,
}

xcb_intern_atom_cooke_t :: struct {
	sequence: uint,
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
	current_reply: [^]reply_list,
	current_reply_tail: [^]^reply_list, 
	replies: [^]_xcb_map,
	events: [^]event_list,
	events_tail: [^]^event_list,
	readers: [^]reader_list,
	special_waiters: [^]special_list,
	pending_replies: [^]pending_reply,
	pending_replies_tail: [^]^pending_reply,
	special_events: [^]xcb_special_event,
}

_xcb_out :: struct {
	cond: unix.pthread_cond_t,
	writing: i32,
	socket_cond: unix.pthread_cond_t,
	return_socket: proc "c" (closure: rawptr),
	socket_closure: rawptr,
	queue: [16384]b8,
	queue_len: i32,
	request: u64,
	request_written: u64,
	reqlenlock: unix.pthread_mutex_t,
	maximum_request_length_tag: Lazy_reply_tag,
	maximum_request_length: struct #raw_union {
		cookie: xcb_big_requests_enable_cookie_t,
	    value: u32,
	},
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

xcb_screen_t :: struct {
	root: xcb_window_t,
	default_color_map: xcb_colormap_t,
	white_pixel: u32,
	black_pixel: u32,
	current_input_masks: u32,
	width_in_pixels: u16,
	height_in_pixels: u16,
	width_in_millimeters: u16,
	height_in_millimeters: u16,
	min_installed_maps: u16,
	max_installed_maps: u16,
	root_visual: xcb_visualid_t,
	backing_stores: u8,
	save_unders: u8,
	root_depth: u8,
	allowed_depths_len: u8,
}

xcb_screen_iterator_t :: struct {
	data: [^]xcb_screen_t,
	rem: i32,
	index: i32,
}

xcb_void_cookie :: struct {
	sequence: uint,
}

@(default_calling_convention="c", private)
foreign xcb {
	xcb_connection_has_error :: proc(^xcb_connection_t) -> i32 ---
	xcb_get_setup :: proc(^xcb_connection_t) -> ^xcb_setup_t ---
	xcb_setup_roots_iterator :: proc(^xcb_setup_t) -> xcb_screen_iterator_t ---
	xcb_screen_next :: proc(^xcb_screen_iterator_t) ---
	xcb_generate_id :: proc(^xcb_connection_t) -> xcb_window_t ---
	xcb_create_window :: proc(^xcb_connection_t, u8, xcb_window_t, xcb_window_t, i16, i16, u16, u16, u16, u16, xcb_visualid_t, u32, rawptr) -> xcb_void_cookie ---
	xcb_map_window :: proc(^xcb_connection_t, xcb_window_t) ---
	xcb_flush :: proc(^xcb_connection_t) -> i32  ---
	xcb_destroy_window :: proc(^xcb_connection_t, xcb_window_t) ---
	xcb_change_property :: proc(^xcb_connection_t, u8, xcb_window_t, xcb_atom_t, xcb_atom_t, u8, u32, rawptr) ---
	xcb_intern_atom_reply :: proc(^xcb_connection_t, xcb_intern_atom_cooke_t, ^^xcb_generic_error_t) -> ^xcb_intern_atom_reply_t ---
	xcb_intern_atom :: proc(^xcb_connection_t, u8, u16, cstring) -> xcb_intern_atom_cooke_t ---
}

@(default_calling_convention="c", private)
foreign X11xcb {
	XGetXCBConnection :: proc(^xlib.Display) -> ^xcb_connection_t ---
}

internal_state :: struct {
	display: ^xlib.Display,
	connection: ^xcb_connection_t,
	window: xcb_window_t,
	screen: ^xcb_screen_t,
    wm_protocols: xcb_atom_t,
	wm_delete_win: xcb_atom_t,
}

platform_state :: struct {
	internal_state: rawptr,
}

xcb_generic_error_t :: struct {
	response_type: u8,
	error_code: u8,
	sequence: u16,
	resource_id: u32,
	minor_code: u16,
	major_code: u8,
	pad0: u8,
	pad: [5]u32,
}

platform_setup :: proc(plat_state: ^platform_state, application_name: cstring, x: i16, y: i16, width: u16, height: u16) -> bool {
	plat_state.internal_state = new(internal_state)
	state : ^internal_state = transmute(^internal_state)plat_state.internal_state
	state.display = xlib.XOpenDisplay(nil)
	// xlib.XAutoRepeatOff(state.display)
	state.connection = XGetXCBConnection(state.display)
	// @TODO use or_error
	if (xcb_connection_has_error(state.connection) == 1) {
		return false
	}

	setup : ^xcb_setup_t = xcb_get_setup(state.connection)
    it : xcb_screen_iterator_t = xcb_setup_roots_iterator(setup)
	screen_p: i32 = 0
	for s := screen_p; s > 0; s =- 1 {
		xcb_screen_next(&it)
	}
	state.screen = it.data
	state.window = xcb_generate_id(state.connection)
	event_mask := mask.XCB_CW_BACK_PIXEL | mask.XCB_CW_EVENT_MASK
	// event_mask := xcb_cw_t.XCB_CW_BACK_PIX.
	event_values := mask2.XCB_EVENT_MASK_BUTTON_PRESS | mask2.XCB_EVENT_MASK_BUTTON_RELEASE |
                       mask2.XCB_EVENT_MASK_KEY_PRESS | mask2.XCB_EVENT_MASK_KEY_RELEASE |
                       mask2.XCB_EVENT_MASK_EXPOSURE | mask2.XCB_EVENT_MASK_POINTER_MOTION |
                       mask2.XCB_EVENT_MASK_STRUCTURE_NOTIFY
	value_list : []u32 = {state.screen.black_pixel, 0}
    cookie: xcb_void_cookie = xcb_create_window(state.connection, 0, state.window, state.screen.root, x, y, width, height, 0, 1, state.screen.root_visual, 11, &value_list)
	xcb_change_property(state.connection, XCB_PROP_MODE_REPLACE, state.window, XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8, len(application_name), application_name)
	wm_delete_cookie : xcb_intern_atom_cooke_t = xcb_intern_atom(state.connection, 0, len("WM_DELETE_WINDOW"), "DELETE_WINDOW")
	wm_protocols_cookie: xcb_intern_atom_cooke_t = xcb_intern_atom(state.connection, 0, len("WM_PROTOCOLS"), "WM_PROTOCOLS")
	wm_delete_reply: ^xcb_intern_atom_reply_t = xcb_intern_atom_reply(state.connection, wm_delete_cookie, nil)
	wm_protocols_reply: ^xcb_intern_atom_reply_t = xcb_intern_atom_reply(state.connection, wm_protocols_cookie, nil)
	state.wm_delete_win = wm_delete_reply.atom
	state.wm_protocols = wm_protocols_reply.atom
	xcb_change_property(state.connection, XCB_PROP_MODE_REPLACE, state.window, wm_protocols_reply.atom, 4, 32, 1, &wm_delete_reply.atom)
	xcb_map_window(state.connection, state.window)
	stream_result: i32 = xcb_flush(state.connection)
	if stream_result <= 0 {
		// l.fatal("An error occured when flushing the stream: %d", stream_result)
		return false
	}
	return true
}

platform_shutdown :: proc(plat_state: ^platform_state) {
	fmt.println("PLATFORM SHUTDOWN")
	state: ^internal_state = transmute(^internal_state)plat_state.internal_state
	xlib.XAutoRepeatOn(state.display)
	xcb_destroy_window(state.connection, state.window)
	defer free(plat_state.internal_state)
}
