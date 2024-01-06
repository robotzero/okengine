// @TODO switch to file tags and not build tags
//+build linux
package core

import "core:sys/unix"
import "core:path/filepath"
import "core:fmt"
import "core:log"
import "core:time"
import "core:strings"
import "core:mem"
import l "../../platform/linux"
import idef "../../engine/core/input"

import xlib "vendor:x11/xlib"

foreign import X11xcb "system:X11-xcb"

@(default_calling_convention="c", private)
foreign X11xcb {
	XGetXCBConnection :: proc(^xlib.Display) -> ^l.Connection ---
}

internal_state :: struct {
	display: ^xlib.Display,
	connection: ^l.Connection,
	window: l.Window,
	screen: ^l.Screen,
    wm_protocols: l.Atom,
	wm_delete_win: l.Atom,
}

platform_state :: struct {
	internal_state: rawptr,
}

platform_startup :: proc(plat_state: ^platform_state, application_name: string, x: i32, y: i32, width: i32, height: i32) -> bool {
	// @TODO use custom allocator? and maybe catch the error
	app_name: cstring = strings.clone_to_cstring(application_name)
	defer delete(app_name)
	plat_state.internal_state = new(internal_state)
	length:= cast(u32)len(application_name)
	state : ^internal_state = cast(^internal_state)plat_state.internal_state
	state.display = xlib.XOpenDisplay(nil)
	xlib.XAutoRepeatOff(state.display)
	screen_p: i32 = 0
	state.connection = XGetXCBConnection(state.display)
	if (l.connection_has_error(state.connection) == 1) {
		return false
	}

	setup : ^l.Setup = l.get_setup(state.connection)
    it : l.ScreenIterator = l.setup_roots_iterator(setup)
	
	for s : i32 = 0; s < screen_p; s -= 1 {
		l.screen_next(&it)
	}
	state.screen = it.data
	state.window = l.generate_id(state.connection)
	event_mask := cast(u32) (l.Cw.BackPixel | l.Cw.EventMask)
	
	event_values := cast(u32) (l.EventMask.ButtonPress | l.EventMask.ButtonRelease |
                       l.EventMask.KeyPress | l.EventMask.KeyRelease |
                       l.EventMask.Exposure | l.EventMask.PointerMotion |
                       l.EventMask.StructureNotify)
	value_list : [3]u32 = {state.screen.blackPixel, event_values, 0}
    cookie: l.VoidCookie = l.create_window(state.connection, cast(u8) l.WindowClass.CopyFromParent, state.window, state.screen.root, cast(i16)x, cast(i16)y, cast(u16)width, cast(u16)height, 0, cast(u16) l.WindowClass.InputOutput, state.screen.rootVisual, event_mask, &value_list[0])
	l.change_property(state.connection, cast(u8) l.PropMode.Replace, state.window, cast(u32) l.AtomEnum.AtomWmName, cast(u32) l.AtomEnum.AtomString, 8, length, cast(rawptr)(app_name))
	wm_delete_cookie : l.InternAtomCookie = l.intern_atom(state.connection, 0, len("WM_DELETE_WINDOW"), "DELETE_WINDOW")
	wm_protocols_cookie: l.InternAtomCookie = l.intern_atom(state.connection, 0, len("WM_PROTOCOLS"), "WM_PROTOCOLS")
	wm_delete_reply: ^l.InternAtomReply = l.intern_atom_reply(state.connection, wm_delete_cookie, nil)
	wm_protocols_reply: ^l.InternAtomReply = l.intern_atom_reply(state.connection, wm_protocols_cookie, nil)
	state.wm_delete_win = wm_delete_reply.atom
	state.wm_protocols = wm_protocols_reply.atom
	l.change_property(state.connection, cast(u8) l.PropMode.Replace, state.window, wm_protocols_reply.atom, 4, 32, 1, &wm_delete_reply.atom)
	l.map_window(state.connection, state.window)
	stream_result: i32 = l.flush(state.connection)
	if stream_result <= 0 {
		// l.fatal("An error occured when flushing the stream: %d", stream_result)
		return false
	}
	return true
}

platform_pump_messages :: proc(plat_state: ^platform_state) -> bool {
	state : ^internal_state = cast(^internal_state)plat_state.internal_state
	quit_flagged := false
	event: ^l.GenericEvent
	cm: ^l.ClientMessageEvent
	event = l.poll_for_event(state.connection)
	if event != nil {
		switch (event.responseType & 0x7f) {
			case l.CLIENT_MESSAGE: {
				cm = cast(^l.ClientMessageEvent) event
				if cm.data.data32[0] == cast(u32)state.wm_delete_win {
					quit_flagged = true
				}
			}
			case l.KEY_PRESS: {
				keyPressEvent := cast(^l.KeyPressEvent) event
				platform_console_write(log.Level.Info, "Hello Denver")
				if keyPressEvent.detail == 9 {
					quit_flagged = true
				}
			}
		}
		// free(event)
		l.flush(state.connection)
	}

	return quit_flagged
}

platform_shutdown :: proc(plat_state: ^platform_state) {
	platform_console_write(log.Level.Info, "Platform Shtudwon")
	state: ^internal_state = cast(^internal_state)plat_state.internal_state
	xlib.XAutoRepeatOn(state.display)
	l.destroy_window(state.connection, state.window)
	defer free(plat_state.internal_state)
}

platform_console_write :: proc(log_level: log.Level, message: string, location := #caller_location) {
	color_strings: []cstring = {"0;41", "1;31", "1;33", "1;32", "1;34", "1;30"}
	colour := 3
	switch log_level {
		case .Info: colour = 3
		case .Debug : colour = 4
		case .Warning : colour = 2
		case .Error: colour = 1
		case .Fatal: colour = 0
	}
	log.logf(log_level, "\033[%sm%s\033[0m", color_strings[colour], message, location = location)
}

platform_console_write_error :: proc(log_level: log.Level, message: string, location := #caller_location) {
	color_strings: []cstring = {"0;41", "1;31", "1;33", "1;32", "1;34", "1;30"}
	colour := 3
	switch log_level {
		case .Info: colour = 3
		case .Debug : colour = 4
		case .Warning : colour = 2
		case .Error: colour = 1
		case .Fatal: colour = 0
	}
	log.logf(log_level, "\033[%sm%s\033[0m", color_strings[colour], message, location = location)
}

platform_get_absolute_time :: proc() -> i64 {
	current_time:= time.now()
	return current_time._nsec
}

platform_sleep :: proc(ms: f64) {
	duration := time.Duration(ms) * time.Millisecond
	time.sleep(duration)
}

platform_allocate :: proc(size: u64, aligned: bool, $T: typeid) -> ^T {
	// log.logf(log.Level.Info, "OBJECT %v", T)
	return new(T)
}

platform_free :: proc(object: ^$T) {
	mem.free(object)
}

platform_zero_memory :: proc(ptr: rawptr, size: int) -> rawptr {
	mem.set(ptr, 0, size)
	return ptr
}

platform_set_memory :: proc(ptr: rawptr, value: byte, size: int) -> rawptr {
	mem.set(ptr, value, size)
	return ptr
}

platform_copy_memory :: proc(dest: rawptr, src: rawptr, size: int) -> rawptr {
	return mem.copy(dest, src, size)
}

// Key translation
translate_keycode :: proc(x_keycode: xlib.KeySym) -> idef.keys {
    #partial switch x_keycode {
        case xlib.KeySym.XK_BackSpace:
			return idef.keys.KEY_BACKSPACE
            // return KEY_BACKSPACE;
        // case XK_Return:
        //     return KEY_ENTER;
        // case XK_Tab:
        //     return KEY_TAB;
        //     //case XK_Shift: return KEY_SHIFT;
        //     //case XK_Control: return KEY_CONTROL;

        // case XK_Pause:
        //     return KEY_PAUSE;
        // case XK_Caps_Lock:
        //     return KEY_CAPITAL;

        // case XK_Escape:
        //     return KEY_ESCAPE;

        //     // Not supported
        //     // case : return KEY_CONVERT;
        //     // case : return KEY_NONCONVERT;
        //     // case : return KEY_ACCEPT;

        // case XK_Mode_switch:
        //     return KEY_MODECHANGE;

        // case XK_space:
        //     return KEY_SPACE;
        // case XK_Prior:
        //     return KEY_PRIOR;
        // case XK_Next:
        //     return KEY_NEXT;
        // case XK_End:
        //     return KEY_END;
        // case XK_Home:
        //     return KEY_HOME;
        // case XK_Left:
        //     return KEY_LEFT;
        // case XK_Up:
        //     return KEY_UP;
        // case XK_Right:
        //     return KEY_RIGHT;
        // case XK_Down:
        //     return KEY_DOWN;
        // case XK_Select:
        //     return KEY_SELECT;
        // case XK_Print:
        //     return KEY_PRINT;
        // case XK_Execute:
        //     return KEY_EXECUTE;
        // // case XK_snapshot: return KEY_SNAPSHOT; // not supported
        // case XK_Insert:
        //     return KEY_INSERT;
        // case XK_Delete:
        //     return KEY_DELETE;
        // case XK_Help:
        //     return KEY_HELP;

        // case XK_Meta_L:
        //     return KEY_LWIN;  // TODO: not sure this is right
        // case XK_Meta_R:
        //     return KEY_RWIN;
        //     // case XK_apps: return KEY_APPS; // not supported

        //     // case XK_sleep: return KEY_SLEEP; //not supported

        // case XK_KP_0:
        //     return KEY_NUMPAD0;
        // case XK_KP_1:
        //     return KEY_NUMPAD1;
        // case XK_KP_2:
        //     return KEY_NUMPAD2;
        // case XK_KP_3:
        //     return KEY_NUMPAD3;
        // case XK_KP_4:
        //     return KEY_NUMPAD4;
        // case XK_KP_5:
        //     return KEY_NUMPAD5;
        // case XK_KP_6:
        //     return KEY_NUMPAD6;
        // case XK_KP_7:
        //     return KEY_NUMPAD7;
        // case XK_KP_8:
        //     return KEY_NUMPAD8;
        // case XK_KP_9:
        //     return KEY_NUMPAD9;
        // case XK_multiply:
        //     return KEY_MULTIPLY;
        // case XK_KP_Add:
        //     return KEY_ADD;
        // case XK_KP_Separator:
        //     return KEY_SEPARATOR;
        // case XK_KP_Subtract:
        //     return KEY_SUBTRACT;
        // case XK_KP_Decimal:
        //     return KEY_DECIMAL;
        // case XK_KP_Divide:
        //     return KEY_DIVIDE;
        // case XK_F1:
        //     return KEY_F1;
        // case XK_F2:
        //     return KEY_F2;
        // case XK_F3:
        //     return KEY_F3;
        // case XK_F4:
        //     return KEY_F4;
        // case XK_F5:
        //     return KEY_F5;
        // case XK_F6:
        //     return KEY_F6;
        // case XK_F7:
        //     return KEY_F7;
        // case XK_F8:
        //     return KEY_F8;
        // case XK_F9:
        //     return KEY_F9;
        // case XK_F10:
        //     return KEY_F10;
        // case XK_F11:
        //     return KEY_F11;
        // case XK_F12:
        //     return KEY_F12;
        // case XK_F13:
        //     return KEY_F13;
        // case XK_F14:
        //     return KEY_F14;
        // case XK_F15:
        //     return KEY_F15;
        // case XK_F16:
        //     return KEY_F16;
        // case XK_F17:
        //     return KEY_F17;
        // case XK_F18:
        //     return KEY_F18;
        // case XK_F19:
        //     return KEY_F19;
        // case XK_F20:
        //     return KEY_F20;
        // case XK_F21:
        //     return KEY_F21;
        // case XK_F22:
        //     return KEY_F22;
        // case XK_F23:
        //     return KEY_F23;
        // case XK_F24:
        //     return KEY_F24;

        // case XK_Num_Lock:
        //     return KEY_NUMLOCK;
        // case XK_Scroll_Lock:
        //     return KEY_SCROLL;

        // case XK_KP_Equal:
        //     return KEY_NUMPAD_EQUAL;

        // case XK_Shift_L:
        //     return KEY_LSHIFT;
        // case XK_Shift_R:
        //     return KEY_RSHIFT;
        // case XK_Control_L:
        //     return KEY_LCONTROL;
        // case XK_Control_R:
        //     return KEY_RCONTROL;
        // // case XK_Menu: return KEY_LMENU;
        // case XK_Menu:
        //     return KEY_RMENU;

        // case XK_semicolon:
        //     return KEY_SEMICOLON;
        // case XK_plus:
        //     return KEY_PLUS;
        // case XK_comma:
        //     return KEY_COMMA;
        // case XK_minus:
        //     return KEY_MINUS;
        // case XK_period:
        //     return KEY_PERIOD;
        // case XK_slash:
        //     return KEY_SLASH;
        // case XK_grave:
        //     return KEY_GRAVE;

        // case XK_a:
        // case XK_A:
        //     return KEY_A;
        // case XK_b:
        // case XK_B:
        //     return KEY_B;
        // case XK_c:
        // case XK_C:
        //     return KEY_C;
        // case XK_d:
        // case XK_D:
        //     return KEY_D;
        // case XK_e:
        // case XK_E:
        //     return KEY_E;
        // case XK_f:
        // case XK_F:
        //     return KEY_F;
        // case XK_g:
        // case XK_G:
        //     return KEY_G;
        // case XK_h:
        // case XK_H:
        //     return KEY_H;
        // case XK_i:
        // case XK_I:
        //     return KEY_I;
        // case XK_j:
        // case XK_J:
        //     return KEY_J;
        // case XK_k:
        // case XK_K:
        //     return KEY_K;
        // case XK_l:
        // case XK_L:
        //     return KEY_L;
        // case XK_m:
        // case XK_M:
        //     return KEY_M;
        // case XK_n:
        // case XK_N:
        //     return KEY_N;
        // case XK_o:
        // case XK_O:
        //     return KEY_O;
        // case XK_p:
        // case XK_P:
        //     return KEY_P;
        // case XK_q:
        // case XK_Q:
        //     return KEY_Q;
        // case XK_r:
        // case XK_R:
        //     return KEY_R;
        // case XK_s:
        // case XK_S:
        //     return KEY_S;
        // case XK_t:
        // case XK_T:
        //     return KEY_T;
        // case XK_u:
        // case XK_U:
        //     return KEY_U;
        // case XK_v:
        // case XK_V:
        //     return KEY_V;
        // case XK_w:
        // case XK_W:
        //     return KEY_W;
        // case XK_x:
        // case XK_X:
        //     return KEY_X;
        // case XK_y:
        // case XK_Y:
        //     return KEY_Y;
        // case XK_z:
        // case XK_Z:
        //     return KEY_Z;
    }
	return idef.keys.KEY_NONCONVERT
}
