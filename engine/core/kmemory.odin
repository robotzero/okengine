package core

import l "./logger"
import pl "../../platform/linux"
import "core:strings"
import "core:fmt"

memory_tag :: enum {
	MEMORY_TAG_UNKNOWN,
	MEMORY_TAG_ARRAY,
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

stats: memory_stats

initialize_memory :: proc() {
	pl.platform_zero_memory(&stats, size_of(memory_stats))
}

shutdown_memory :: proc() {
	
}

kallocate :: proc(size: u64, tag: memory_tag, $T: typeid) -> ^T {
	if tag == .MEMORY_TAG_UNKNOWN {
		l.log_warning("kallocate called using MEMORY_TAG_UNKNOWN. Re-class this allocation.")
	}

	stats.total_allocated += size
	stats.tagged_allocations[tag] += size

	block:= pl.platform_allocate(size, false, T)
	pl.platform_zero_memory(block, cast(int)size)

	return block
}

kfree :: proc(object: $T, size: u64, tag: memory_tag) {
	if tag == .MEMORY_TAG_UNKNOWN {
		l.log_warning("kfree called using MEMORY_TAG_UNKNOWN. Re-class this allocation.")
	}

	stats.total_allocated -= size
	stats.tagged_allocations[tag] -= size

	pl.platform_free(object)
}

kzero_memory :: proc (block: rawptr, size: int) -> rawptr {
	return pl.platform_zero_memory(block, size)
}

kcopy_memory :: proc(dest: rawptr, source: rawptr, size: int) -> rawptr {
	return pl.platform_copy_memory(dest, source, size)
}

kset_memory :: proc(ptr: rawptr, value: byte, size: int) {
	pl.platform_set_memory(ptr, value, size)
}

get_memory_usage_str :: proc() -> string {
	gib :: 1024 * 1024 * 1024
	mib :: 1024 * 1024
	kib :: 1024 * 1024

	msg : string
	//@TODO handle error from strings.concatenate
	for i:=0; i< cast(int)memory_tag.MEMORY_TAG_MAX_TAGS; i = i + 1 {
		unit : string
		amount : u64 = 1.0

		if stats.tagged_allocations[i] >= gib {
			unit = "GiB"
			amount = stats.tagged_allocations[i] / gib
		} else if stats.tagged_allocations[i] >= mib {
			unit = "MiB"
			amount = stats.tagged_allocations[i] / mib
		} else if stats.tagged_allocations[i] >= kib {
			unit = "KiB"
			amount = stats.tagged_allocations[i] / kib
		} else {
			unit = "B0"
			amount = stats.tagged_allocations[i]
		}
		msg = strings.concatenate({msg, fmt.tprintf("System memory user (tagged):\n %s: %.2fs\n", memory_tag_strings[i], amount, unit)})
	}
	return msg
}
