package parser

import "base:runtime"
import "stack"
import types "stock_types"
import "tokens"

parse_type_from_identifier :: proc(name: string) -> types.Types {
	switch name {
	case "unit":
		return types.Unit{}
	case "bool":
		return types.Bool{}
	case "int":
		return types.Integer{}
	case "i8":
		return types.Integer8{}
	case "i32":
		return types.Integer32{}
	case "i64":
		return types.Integer64{}
	case "f32":
		return types.Float32{}
	case "f64":
		return types.Float64{}
	case "string":
		return types.String{}
	}

	return types.Custom_Type{name = name}
}


parse_type :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> types.Types {
	Modifier_Kind :: enum {
		Pointer,
		Array,
	}

	Modifier :: struct {
		kind:       Modifier_Kind,
		count_kind: types.Array_Count_Kind,
		count:      int,
	}

	modifiers := stack.make_stack(Modifier, context.temp_allocator)
	defer stack.destroy_stack(&modifiers)

	base_type: types.Types

	// collect type modifiers left to right
	type_parsing_loop: for {
		token := next_token(tokenizer, arena)

		#partial switch t in token {
		case tokens.Caret:
			stack.push(&modifiers, Modifier{kind = .Pointer})

		case tokens.Open_SB:
			count_kind := types.Array_Count_Kind.Fixed
			count := 0

			next := peek_token(tokenizer, arena)

			#partial switch nt in next {
			case tokens.Close_SB:
				next_token(tokenizer, arena)
				count_kind = .Slice

			case tokens.Question:
				next_token(tokenizer, arena)

				if _, ok := next_token(tokenizer, arena).(tokens.Close_SB); !ok {
					panic("expected ']' after '?' in array type")
				}

				count_kind = .Infer

			case tokens.Identifier:
				if nt.content == "dynamic" {
					next_token(tokenizer, arena)

					if _, ok := next_token(tokenizer, arena).(tokens.Close_SB); !ok {
						panic("expected ']' after dynamic in array type")
					}

					count_kind = .Dynamic
				} else {
					panic("expected array count, '?', 'dynamic', or ']'")
				}

			case tokens.Int_Literal:
				next_token(tokenizer, arena)

				if nt.content < 0 {
					panic("array count cannot be negative")
				}

				count = int(nt.content)

				if _, ok := next_token(tokenizer, arena).(tokens.Close_SB); !ok {
					panic("expected ']' after array count")
				}

				count_kind = .Fixed

			case:
				panic("expected array count, '?', 'dynamic', or ']'")
			}

			stack.push(&modifiers, Modifier{kind = .Array, count_kind = count_kind, count = count})

		case tokens.Identifier:
			base_type = parse_type_from_identifier(t.content)
			break type_parsing_loop // this is why shiver wont have fallthrough

		case:
			panic("expected a valid type identifier or type modifier")
		}
	}

	// churnmaxxing through the stack
	current_type := base_type
	for !stack.is_empty(&modifiers) {
		m, _ := stack.pop(&modifiers)

		switch m.kind {
		case .Pointer:
			current_type = types.Pointer {
				elem = new_clone(current_type, arena),
			}
		case .Array:
			current_type = types.Array {
				count_kind = m.count_kind,
				count      = m.count,
				elem       = new_clone(current_type, arena),
			}
		}
	}

	return current_type
}
