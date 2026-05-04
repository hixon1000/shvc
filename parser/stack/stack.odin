package stack

import "base:runtime"

Node :: struct($T: typeid) {
	value: T,
	next:  ^Node(T),
}

Stack :: struct($T: typeid) {
	top:       ^Node(T),
	len:       int,
	allocator: runtime.Allocator,
}

make_stack :: proc($T: typeid, allocator: runtime.Allocator) -> Stack(T) {
	return Stack(T){allocator = allocator}
}

push :: proc(s: ^Stack($T), val: T) {
	new_node := new(Node(T), s.allocator)
	new_node.value = val
	new_node.next = s.top

	s.top = new_node
	s.len += 1
}

peek :: proc(s: ^Stack($T)) -> (T, bool) {
	if s.top == nil {
		return {}, false
	}
	return s.top.value, true
}

pop :: proc(s: ^Stack($T)) -> (val: T, ok: bool) {
	if s.top == nil {
		return {}, false
	}

	old_top := s.top
	val = old_top.value
	s.top = old_top.next

	free(old_top, s.allocator) // cleanup
	s.len -= 1
	return val, true
}

destroy_stack :: proc(s: ^Stack($T)) {
	for s.top != nil {
		pop(s)
	}
}
