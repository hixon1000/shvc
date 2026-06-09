package parser

import "ast"
import "base:runtime"
import "tokens"

parse_array_literal :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	// opening { should have been consumed

	items_ptr := new([dynamic]^ast.AST_Node, arena)
	items_ptr^ = make([dynamic]^ast.AST_Node, arena)

	if _, empty := peek_token(tokenizer, arena).(tokens.Close_Bracket); empty {
		next_token(tokenizer, arena)
	} else {
		for {
			item := parse_expression(tokenizer, arena)
			append(items_ptr, item)

			sep := next_token(tokenizer, arena)

			#partial switch _ in sep {
			case tokens.Comma:
				// allow trailing comma
				if _, is_end := peek_token(tokenizer, arena).(tokens.Close_Bracket); is_end {
					next_token(tokenizer, arena)
					break
				}
				continue

			case tokens.Close_Bracket:
				break

			case:
				panic("expected ',' or '}' in array literal")
			}

			break
		}
	}

	node := new(ast.AST_Node, arena)
	node^ = ast.Array_Literal {
		items = items_ptr,
	}
	return node
}
