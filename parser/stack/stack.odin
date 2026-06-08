package stack

import "base:runtime"

Stack :: struct($T: typeid) {
	data:      []T,
	len:       int,
	allocator: runtime.Allocator,
}

make_stack :: proc($T: typeid, allocator: runtime.Allocator) -> Stack(T) {
	return Stack(T){data = nil, len = 0, allocator = allocator}
}

push :: proc(s: ^Stack($T), val: T) {
	if s.len == len(s.data) {
		stack_grow(s)
	}

	s.data[s.len] = val
	s.len += 1
}

peek :: proc(s: ^Stack($T)) -> (T, bool) {
	if s.len == 0 {
		return {}, false
	}

	return s.data[s.len - 1], true
}

pop :: proc(s: ^Stack($T)) -> (val: T, ok: bool) {
	if s.len == 0 {
		return {}, false
	}

	s.len -= 1
	val = s.data[s.len]

	return val, true
}

destroy_stack :: proc(s: ^Stack($T)) {
	if s.data != nil {
		delete(s.data, s.allocator)
	}

	s.data = nil
	s.len = 0
}

is_empty :: proc(s: ^Stack($T)) -> bool {
	return s.len == 0
}

stack_grow :: proc(s: ^Stack($T)) {
	old_cap := len(s.data)

	new_cap := 8
	if old_cap > 0 {
		new_cap = old_cap * 2
	}

	new_data := make([]T, new_cap, s.allocator)

	if s.data != nil {
		copy(new_data[:s.len], s.data[:s.len])
		delete(s.data, s.allocator)
	}

	s.data = new_data
}
