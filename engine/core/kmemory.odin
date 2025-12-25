package core

import "core:fmt"
import "core:strings"

@(private = "file")
memory_state_ptr: ^memory_system_state

memory_system_state :: struct {
	stats:       memory_stats,
	alloc_count: u64,
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

initialize_memory :: proc(
	state: ^memory_system_state,
	allocator := context.allocator,
	location := #caller_location,
) -> ^memory_system_state {
	memory_state_ptr = state
	memory_state_ptr.alloc_count = 0
	// TODO zero this crap
	platform_zero_memory(&memory_state_ptr.stats, size_of(memory_stats))
	return memory_state_ptr
}

shutdown_memory :: proc(alloc: ^linear_allocator, allocator := context.allocator) {
	platform_free(app_state)
	// linear_allocator_free_all(linear_allocator.allocator)
	// linear_allocator_destroy(alloc)
}

kallocate :: proc(
	tag: memory_tag,
	$T: typeid,
	allocator := context.allocator,
	location := #caller_location,
) -> ^T {
	if tag == .MEMORY_TAG_UNKNOWN {
		log_warning("kallocate called using MEMORY_TAG_UNKNOWN. Re-class this allocation.")
	}

	if memory_state_ptr != nil {
		memory_state_ptr.stats.total_allocated += size_of(T)
		memory_state_ptr.stats.tagged_allocations[tag] += size_of(T)
		memory_state_ptr.alloc_count = memory_state_ptr.alloc_count + 1
	}

	obj, err := platform_allocate(false, T, allocator, location)

	ensure(err == nil)

	return obj
}

kfree :: proc(object: ^$T, size: u64, tag: memory_tag) {
	if tag == .MEMORY_TAG_UNKNOWN {
		log_warning("kfree called using MEMORY_TAG_UNKNOWN. Re-class this allocation.")
	}

	memory_state_ptr.stats.total_allocated -= size
	memory_state_ptr.stats.tagged_allocations[tag] -= size

	platform_free(object)
}

kzero_memory :: proc(block: rawptr, size: int) -> rawptr {
	//@TODO missing stuff
	return platform_zero_memory(block, size)
}

get_memory_alloc_count :: proc() -> u64 {
	if memory_state_ptr != nil {
		return memory_state_ptr.alloc_count
	}
	return 0
}

kcopy_memory :: proc(dest: rawptr, source: rawptr, size: int) -> rawptr {
	return platform_copy_memory(dest, source, size)
}

kset_memory :: proc(ptr: rawptr, value: byte, size: int) {
	platform_set_memory(ptr, value, size)
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
		log_error("Unable to get memory usage", err)
		str = ""
	}
	return str
}

