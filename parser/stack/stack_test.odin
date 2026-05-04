package stack

import "core:testing"

@(test)
test_stack_push_pop :: proc(t: ^testing.T) {
	s := make_stack(int, context.allocator)
	defer destroy_stack(&s)

	testing.expectf(t, s.len == 0, "expected length 0, got %v", s.len)

	push(&s, 10)
	push(&s, 20)
	testing.expectf(t, s.len == 2, "expected length 2, got %v", s.len)

	val, ok := peek(&s)
	testing.expect(t, ok, "peek failed on non empty stack")
	testing.expectf(t, val == 20, "expected peek to return 20, got %v", val)

	val, ok = pop(&s)
	testing.expect(t, ok, "pop failed on non-empty stack")
	testing.expectf(t, val == 20, "expected popped value 20, got %v", val)
	testing.expectf(t, s.len == 1, "expected length 1 after pop, got %v", s.len)

	pop(&s)
	_, ok = pop(&s)
	testing.expect(t, !ok, "pop should return false on empty stack")
}
