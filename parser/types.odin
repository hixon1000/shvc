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

package parser

import "base:runtime"
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
	token := next_token(tokenizer, arena)

	#partial switch t in token.kind {
	case tokens.Caret:
		elem_type := parse_type(tokenizer, arena)
		return types.Pointer{elem = new_clone(elem_type, arena)}

	case tokens.Open_SB:
		count_kind := types.Array_Count_Kind.Fixed
		count := 0

		next := peek_token(tokenizer, arena)

		#partial switch nt in next.kind {
		case tokens.Close_SB:
			// []i32
			next_token(tokenizer, arena)
			count_kind = .Slice

		case tokens.Question:
			// [?]i32
			next_token(tokenizer, arena)

			if _, ok := next_token(tokenizer, arena).kind.(tokens.Close_SB); !ok {
				panic("expected ']' after '?' in array type")
			}

			count_kind = .Infer

		case tokens.Identifier:
			// [dynamic]i32
			if nt.content == "dynamic" {
				next_token(tokenizer, arena)

				if _, ok := next_token(tokenizer, arena).kind.(tokens.Close_SB); !ok {
					panic("expected ']' after dynamic in array type")
				}

				count_kind = .Dynamic
			} else {
				panic("expected array count, '?', 'dynamic', or ']'")
			}

		case tokens.Int_Literal:
			// [3]i32
			next_token(tokenizer, arena)

			if nt.content < 0 {
				panic("array count cannot be negative")
			}

			count = int(nt.content)

			if _, ok := next_token(tokenizer, arena).kind.(tokens.Close_SB); !ok {
				panic("expected ']' after array count")
			}

			count_kind = .Fixed

		case:
			panic("expected array count, '?', 'dynamic', or ']'")
		}

		elem_type := parse_type(tokenizer, arena)

		return types.Array {
			count_kind = count_kind,
			count = count,
			elem = new_clone(elem_type, arena),
		}

	case tokens.Identifier:
		return parse_type_from_identifier(t.content)

	case:
		panic("expected a valid type identifier or type modifier")
	}
}
