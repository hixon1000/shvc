package stack

import "core:testing"

@(test)
test_stack_basic_push_pop :: proc(t: ^testing.T) {
	s := make_stack(int, context.allocator)
	defer destroy_stack(&s)

	testing.expectf(t, s.len == 0, "expected length 0, got %v", s.len)

	push(&s, 10)
	push(&s, 20)
	testing.expectf(t, s.len == 2, "expected length 2, got %v", s.len)

	val, ok := peek(&s)
	testing.expect(t, ok, "peek failed on non-empty stack")
	testing.expectf(t, val == 20, "expected peek to return 20, got %v", val)

	val, ok = pop(&s)
	testing.expect(t, ok, "pop failed on non-empty stack")
	testing.expectf(t, val == 20, "expected popped value 20, got %v", val)
	testing.expectf(t, s.len == 1, "expected length 1 after pop, got %v", s.len)

	pop(&s)
	_, ok = pop(&s)
	testing.expect(t, !ok, "pop should return false on empty stack")
}

@(test)
test_stack_large_scale_lifo :: proc(t: ^testing.T) {
	s := make_stack(int, context.allocator)
	defer destroy_stack(&s)

	// something big
	COUNT :: 10_000

	for i in 0 ..< COUNT {
		push(&s, i)
	}
	testing.expectf(t, s.len == COUNT, "expected length %v, got %v", COUNT, s.len)

	// peek the top element before emptying
	top_val, peek_ok := peek(&s)
	testing.expect(t, peek_ok, "peek failed on full stack")
	testing.expectf(t, top_val == COUNT - 1, "expected top element %v, got %v", COUNT - 1, top_val)

	// pop to verify lifo
	for i := COUNT - 1; i >= 0; i -= 1 {
		val, pop_ok := pop(&s)
		testing.expectf(t, pop_ok, "pop failed prematurely at index %v", i)
		testing.expectf(t, val == i, "lifo violation, expected %v, got %v", i, val)
	}

	testing.expectf(
		t,
		s.len == 0,
		"expected stack to be completely empty, but length is %v",
		s.len,
	)
	testing.expect(t, is_empty(&s), "is_empty() returned false on an empty stack")
}

// churnmaxxing
@(test)
test_stack_interleaved_churn :: proc(t: ^testing.T) {
	s := make_stack(int, context.allocator)
	defer destroy_stack(&s)

	expected_len := 0

	for cycle in 0 ..< 200 {
		for i in 0 ..< 8 {
			push(&s, cycle * 10 + i)
			expected_len += 1
		}
		testing.expectf(
			t,
			s.len == expected_len,
			"length mismatch after push phase in cycle %v",
			cycle,
		)

		for _ in 0 ..< 5 {
			_, ok := pop(&s)
			testing.expect(t, ok, "pop failed during interleaved churn phase")
			expected_len -= 1
		}
		testing.expectf(
			t,
			s.len == expected_len,
			"length mismatch after pop phase in cycle %v",
			cycle,
		)
	}

	// cleanup
	for s.len > 0 {
		pop(&s)
	}
	testing.expect(t, is_empty(&s), "stack failed to clear properly after interleaved churn")
}

@(test)
test_stack_underflow_and_boundary_abuse :: proc(t: ^testing.T) {
	s := make_stack(int, context.allocator)
	defer destroy_stack(&s)

	// spammaxx pop and peek on a completely fresh, empty stack
	for _ in 0 ..< 50 {
		_, pop_ok := pop(&s)
		testing.expect(t, !pop_ok, "pop falsely reported success on an empty stack")

		_, peek_ok := peek(&s)
		testing.expect(t, !peek_ok, "peek falsely reported success on an empty stack")

		testing.expectf(
			t,
			s.len == 0,
			"stack length drifted below zero, current length: %v",
			s.len,
		)
	}

	for i in 0 ..< 100 {
		push(&s, i)
		testing.expectf(t, s.len == 1, "expected length 1, got %v", s.len)

		val, ok := pop(&s)
		testing.expect(t, ok, "failed to pop single item")
		testing.expectf(t, val == i, "expected %v, got %v", i, val)
		testing.expectf(t, s.len == 0, "expected length 0, got %v", s.len)
	}
}
