package core

import l "../logger"
import m "../memory"
import p "../platform/linux"
import "core:fmt"
import "core:strings"

@(private = "file")
memory_state_ptr: ^memory_system_state

memory_system_configuration :: struct {
	total_alloc_size: u64,
}

memory_system_state :: struct {
	config:    memory_system_configuration,
	stats:     memory_stats,
	alloc_count: u64,
	allocator: m.dynamic_allocator,
}

memory_stats :: struct {
	total_allocated:    u64,
	tagged_allocations: [memory_tag.MEMORY_TAG_MAX_TAGS]u64,
}

memory_tag :: enum {
	MEMORY_TAG_UNKNOWN,
	MEMORY_TAG_ARRAY,
	MEMORY_TAG_ALLC,
	MEMORY_TAG_DARRAY,
	MEMORY_TAG_DICT,
	MEMORY_TAG_RING_QUEUE,
	MEMORY_TAG_BST,
	MEMORY_TAG_STRING,
	MEMORY_TAG_APPLICATION,
	MEMORY_TAG_LINEAR_ALLOCATOR,
	MEMORY_TAG_JOB,
	MEMORY_TAG_TEXTURE,
	MEMORY_TAG_MATERIAL_INSTANCE,
	MEMORY_TAG_RENDERER,
	MEMORY_TAG_GAME,
	MEMORY_TAG_TRANSFORM,
	MEMORY_TAG_ENTITY,
	MEMORY_TAG_ENTITY_NODE,
	MEMORY_TAG_SCENE,
	MEMORY_TAG_MAX_TAGS,
}

memory_tag_strings: [memory_tag.MEMORY_TAG_MAX_TAGS]string = {
	"UNKNOWN   ",
	"ARRAY     ",
	"ALLC      ",
	"DARRAY    ",
	"DICT      ",
	"RING_QUEUE ",
	"BST        ",
	"STRING     ",
	"APPLICATION",
	"LINEAR_ALLOCATOR",
	"JOB        ",
	"TEXTURE    ",
	"MAT_INST   ",
	"RENDERER   ",
	"GAME       ",
	"TRANSFORM  ",
	"ENTITY     ",
	"ENTITY_NODE",
	"SCENE      ",
}

memory_system_initialize :: proc(config: memory_system_configuration) -> bool {
	// Allocate the state itself from the platform allocator; we need it to
	// exist before the dynamic allocator is up so early kallocate calls have
	// somewhere to write statistics.
	state, err := p.platform_allocate(false, memory_system_state)
	if err != nil {
		l.log_fatal("Memory system state allocation failed; system cannot continue.")
		return false
	}

	state.config = config
	state.alloc_count = 0
	p.platform_zero_memory(&state.stats, size_of(memory_stats))

	if !m.dynamic_allocator_create(config.total_alloc_size, &state.allocator) {
		l.log_fatal("Memory system is unable to setup internal allocator. Application cannot continue.")
		p.platform_free(state)
		return false
	}

	memory_state_ptr = state
	l.log_debug("Memory system successfully allocated %d bytes.", config.total_alloc_size)
	return true
}

memory_system_shutdown :: proc() {
	if memory_state_ptr == nil {
		return
	}
	m.dynamic_allocator_destroy(&memory_state_ptr.allocator)
	p.platform_free(memory_state_ptr)
	memory_state_ptr = nil
}

kallocate :: proc(
	tag: memory_tag,
	$T: typeid,
	location := #caller_location,
) -> ^T {
	if tag == .MEMORY_TAG_UNKNOWN {
		l.log_warning("kallocate called using MEMORY_TAG_UNKNOWN. Re-class this allocation.")
	}

	sz :: u64(size_of(T))

	if memory_state_ptr != nil {
		memory_state_ptr.stats.total_allocated += sz
		memory_state_ptr.stats.tagged_allocations[tag] += sz
		memory_state_ptr.alloc_count += 1

		block := m.dynamic_allocator_allocate(&memory_state_ptr.allocator, sz)
		if block == nil {
			l.log_fatal("kallocate failed to allocate successfully.")
			return nil
		}
		return (^T)(raw_data(block))
	}

	// Memory system not yet up — fall back to platform allocator.
	l.log_warning("kallocate called before the memory system is initialized.")
	obj, err := p.platform_allocate(false, T)
	ensure(err == nil)
	return obj
}

kfree :: proc(
	object: ^$T,
	size: u64,
	tag: memory_tag,
	location := #caller_location,
) {
	if tag == .MEMORY_TAG_UNKNOWN {
		l.log_warning("kfree called using MEMORY_TAG_UNKNOWN. Re-class this allocation.")
	}

	if memory_state_ptr != nil {
		memory_state_ptr.stats.total_allocated -= size
		memory_state_ptr.stats.tagged_allocations[tag] -= size

		// Reconstruct the aligned byte slice — must match what dynamic_allocator_allocate
		// registered with the freelist (rounded up to DYNAMIC_ALLOCATOR_ALIGNMENT).
		aligned_size :=
			(size + m.DYNAMIC_ALLOCATOR_ALIGNMENT - 1) &
			~u64(m.DYNAMIC_ALLOCATOR_ALIGNMENT - 1)
		block := ([^]u8)(object)[:aligned_size]
		if !m.dynamic_allocator_free(&memory_state_ptr.allocator, block) {
			// Pointer is outside our arena — was allocated before the memory
			// system came up, so fall back to platform free.
			p.platform_free(object)
		}
		return
	}

	p.platform_free(object)
}

kzero_memory :: proc(block: rawptr, size: int) -> rawptr {
	//@TODO missing stuff
	return p.platform_zero_memory(block, size)
}

get_memory_alloc_count :: proc() -> u64 {
	if memory_state_ptr != nil {
		return memory_state_ptr.alloc_count
	}
	return 0
}

kcopy_memory :: proc(dest: rawptr, source: rawptr, size: int) -> rawptr {
	return p.platform_copy_memory(dest, source, size)
}

kset_memory :: proc(ptr: rawptr, value: byte, size: int) {
	p.platform_set_memory(ptr, value, size)
}

get_memory_usage_str :: proc() -> string {
	gib :: 1024 * 1024 * 1024
	mib :: 1024 * 1024
	kib :: 1024 * 1024

	msg: [len(memory_state_ptr.stats.tagged_allocations) + 1]string
	#no_bounds_check {
		msg[0] = "\n"
	}
	if memory_state_ptr == nil {
		return ""
	}
	for v, i in memory_state_ptr.stats.tagged_allocations {
		unit: string
		amount: f64 = 1.0
		message: string

		if v >= gib {
			unit = "GiB"
			amount = cast(f64)v / gib
		} else if cast(f64)v >= mib {
			unit = "MiB"
			amount = cast(f64)v / mib
		} else if v >= kib {
			unit = "KiB"
			amount = cast(f64)v / kib
		} else {
			unit = "B0"
			amount = cast(f64)v
		}

		formatted_message := fmt.tprintf(
			"System memory user (tagged):\n %s: %.2f %s\n",
			memory_tag_strings[i],
			amount,
			unit,
		)
		#no_bounds_check {
			msg[i + 1] = formatted_message
		}
	}

	str, err := strings.concatenate(msg[:])
	defer if err != nil {
		l.log_error("Unable to get memory usage", err)
		str = ""
	}
	return str
}

