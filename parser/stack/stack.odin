/*
   Copyright 2026 Shiver Contributors

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

package stack

import "base:runtime"

Stack :: struct($T: typeid) {
	data:      []T,
	len:       int,
	allocator: runtime.Allocator,
}

// nobody is going to nest it more than 16 times right?
make_stack :: proc($T: typeid, allocator: runtime.Allocator, capacity: int = 16) -> Stack(T) {
	data: []T = nil
	if capacity > 0 {
		data = make([]T, capacity, allocator)
	}
	return Stack(T){data = data, len = 0, allocator = allocator}
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
