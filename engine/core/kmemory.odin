package core

import "core:strings"
import "core:fmt"

@(private="file")
stats: memory_stats
@(private="file")
state_ptr: ^memory_system_state

memory_system_state :: struct {
	stats: memory_stats,
	alloc_count: u64,
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

memory_stats :: struct {
	total_allocated: u64,
	tagged_allocations: [memory_tag.MEMORY_TAG_MAX_TAGS]u64,
}

memory_tag_strings : [memory_tag.MEMORY_TAG_MAX_TAGS]string = {
	"UNKNOWN   ",
    "ARRAY     ",
	"ALLC      ",
	"DARRAY    ",
	"RING_QUEUE ",
	"BST        ",
    "STRING     ",
    "APPLICATION",
    "JOB        ",
    "TEXTURE    ",
    "MAT_INST   ",
    "RENDERER   ",
    "GAME       ",
    "TRANSFORM  ",
    "ENTITY     ",
    "ENTITY_NODE",
    "SCENE      ",
	"NOP        ",
}

initialize_memory :: proc(memory_requirement: ^u64, $T: typeid, allocator := context.allocator, location := #caller_location) -> ^T {
	memory_requirement^ = size_of(memory_system_state)
	if memory_requirement == nil {
		return nil
	}

	state_ptr = platform_allocate(memory_requirement^, false, T, allocator, location)
	state_ptr.alloc_count = 0
	platform_zero_memory(&stats, size_of(memory_stats))
	return state_ptr
}

shutdown_memory :: proc(alloc: ^linear_allocator, allocator := context.allocator) {
	linear_allocator_free_all(alloc)
	free_all(context.allocator)
	platform_free(state_ptr)
	platform_free(app_state)
	// linear_allocator_destroy(alloc)
	state_ptr = nil
}

kallocate :: proc(size: u64, tag: memory_tag, $T: typeid, location := #caller_location) -> ^T {
	if tag == .MEMORY_TAG_UNKNOWN {
		log_warning("kallocate called using MEMORY_TAG_UNKNOWN. Re-class this allocation.")
	}

	if state_ptr != nil {
		state_ptr.stats.total_allocated += size
		state_ptr.stats.tagged_allocations[tag] += size
		state_ptr.alloc_count = state_ptr.alloc_count + 1
	}

	block := platform_allocate(size, false, T, location = location)

	return block
}

kfree :: proc(object: ^$T, size: u64, tag: memory_tag) {
	if tag == .MEMORY_TAG_UNKNOWN {
		log_warning("kfree called using MEMORY_TAG_UNKNOWN. Re-class this allocation.")
	}

	state_ptr.stats.total_allocated -= size
	state_ptr.stats.tagged_allocations[tag] -= size

	platform_free(object)
}

kzero_memory :: proc (block: rawptr, size: int) -> rawptr {
	//@TODO missing stuff
	return platform_zero_memory(block, size)
}

get_memory_alloc_count :: proc() -> u64 {
	if state_ptr != nil {
		return state_ptr.alloc_count
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

	msg : [len(stats.tagged_allocations) + 1]string
	#no_bounds_check {
		msg[0] = "\n"
	}
	//@TODO handle error from strings.concatenate
	for v, i in state_ptr.stats.tagged_allocations {
		unit : string
		amount : f64 = 1.0
		message : string

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

		formatted_message := fmt.tprintf("System memory user (tagged):\n %s: %.2f %s\n", memory_tag_strings[i], amount, unit)
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
