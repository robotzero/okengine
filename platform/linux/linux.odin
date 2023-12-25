// @TODO switch to file tags and not build tags
//+build linux
package platform

import xlib "vendor:x11/xlib"
import "core:sys/unix"
import "core:path/filepath"
import "core:fmt"
// import l "../engine/core/logger"
foreign import X11xcb "system:X11-xcb"

@(default_calling_convention="c", private)
foreign X11xcb {
	XGetXCBConnection :: proc(^xlib.Display) -> ^Connection ---
}

internal_state :: struct {
	display: ^xlib.Display,
	connection: ^Connection,
	window: Window,
	screen: ^Screen,
    wm_protocols: Atom,
	wm_delete_win: Atom,
}

platform_state :: struct {
	internal_state: rawptr,
}

platform_setup :: proc(plat_state: ^platform_state, application_name: cstring, x: i16, y: i16, width: u16, height: u16) -> bool {
	plat_state.internal_state = new(internal_state)
	length:= cast(u32)len(application_name)
	state : ^internal_state = cast(^internal_state)plat_state.internal_state
	state.display = xlib.XOpenDisplay(nil)
	xlib.XAutoRepeatOff(state.display)
	screen_p: i32 = 0
	state.connection = XGetXCBConnection(state.display)
	// state.connection = connect(nil, &screen_p)
	// @TODO use or_error
	if (connection_has_error(state.connection) == 1) {
		return false
	}

	setup : ^Setup = get_setup(state.connection)
    it : ScreenIterator = setup_roots_iterator(setup)
	
	for s : i32 = 0; s < screen_p; s -= 1 {
		screen_next(&it)
	}
	state.screen = it.data
	state.window = generate_id(state.connection)
	event_mask := cast(u32) (Cw.BackPixel | Cw.EventMask)
	
	event_values := cast(u32) (EventMask.ButtonPress | EventMask.ButtonRelease |
                       EventMask.KeyPress | EventMask.KeyRelease |
                       EventMask.Exposure | EventMask.PointerMotion |
                       EventMask.StructureNotify)
	value_list : [3]u32 = {state.screen.blackPixel, event_values, 0}
    cookie: VoidCookie = create_window(state.connection, cast(u8) WindowClass.CopyFromParent, state.window, state.screen.root, x, y, width, height, 0, cast(u16) WindowClass.InputOutput, state.screen.rootVisual, event_mask, &value_list[0])
	change_property(state.connection, cast(u8) PropMode.Replace, state.window, cast(u32) AtomEnum.AtomWmName, cast(u32) AtomEnum.AtomString, 8, length, transmute(rawptr)(application_name))
	wm_delete_cookie : InternAtomCookie = intern_atom(state.connection, 0, len("WM_DELETE_WINDOW"), "DELETE_WINDOW")
	wm_protocols_cookie: InternAtomCookie = intern_atom(state.connection, 0, len("WM_PROTOCOLS"), "WM_PROTOCOLS")
	wm_delete_reply: ^InternAtomReply = intern_atom_reply(state.connection, wm_delete_cookie, nil)
	wm_protocols_reply: ^InternAtomReply = intern_atom_reply(state.connection, wm_protocols_cookie, nil)
	state.wm_delete_win = wm_delete_reply.atom
	state.wm_protocols = wm_protocols_reply.atom
	change_property(state.connection, cast(u8) PropMode.Replace, state.window, wm_protocols_reply.atom, 4, 32, 1, &wm_delete_reply.atom)
	map_window(state.connection, state.window)
	stream_result: i32 = flush(state.connection)
	if stream_result <= 0 {
		// l.fatal("An error occured when flushing the stream: %d", stream_result)
		return false
	}
	return true
}

platform_pump_messages :: proc(plat_state: ^platform_state) -> bool {
	state : ^internal_state = cast(^internal_state)plat_state.internal_state
	quit_flagged := false
	event: ^GenericEvent
	cm: ^ClientMessageEvent
	event = poll_for_event(state.connection)
	if event != nil {
		switch (event.responseType & 0x7f) {
			case CLIENT_MESSAGE: {
				cm = cast(^ClientMessageEvent) event
				if cm.data.data32[0] == cast(u32)state.wm_delete_win {
					quit_flagged = true
				}
			}
			case KEY_PRESS: {
				keyPressEvent := cast(^KeyPressEvent) event
				fmt.println("HELLO DENVER")
				if keyPressEvent.detail == 9 {
					quit_flagged = true
				}
			}
		}
		// free(event)
		flush(state.connection)
	}

	return quit_flagged
}

platform_shutdown :: proc(plat_state: ^platform_state) {
	fmt.println("PLATFORM SHUTDOWN")
	state: ^internal_state = cast(^internal_state)plat_state.internal_state
	xlib.XAutoRepeatOn(state.display)
	destroy_window(state.connection, state.window)
	defer free(plat_state.internal_state)
}
