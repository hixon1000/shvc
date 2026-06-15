package parser

import "ast"
import "base:runtime"
import "tokens"

parse_postfix_expr :: proc(
	tokenizer: ^Tokenizer,
	arena: runtime.Allocator,
	base: ^ast.AST_Node,
) -> ^ast.AST_Node {
	result := base

	for {
		next := peek_token(tokenizer, arena)

		#partial switch _ in next.kind {
		case tokens.Dot:
			next_token(tokenizer, arena) // consume .

			field_tok, ok := next_token(tokenizer, arena).kind.(tokens.Identifier)
			if !ok {
				panic("expected identifier after '.'")
			}

			// method call expr.name()
			if _, is_call := peek_token(tokenizer, arena).kind.(tokens.Open_Paren); is_call {
				next_token(tokenizer, arena) // consume (

				args_list := new([dynamic]^ast.AST_Node, arena)
				args_list^ = make([dynamic]^ast.AST_Node, arena)

				if _, empty := peek_token(tokenizer, arena).kind.(tokens.Close_Paren); !empty {
					for {
						arg_expr := parse_expression(tokenizer, arena)
						append(args_list, arg_expr)

						sep := next_token(tokenizer, arena)
						#partial switch _ in sep.kind {
						case tokens.Comma:
							continue
						case tokens.Close_Paren:
							break
						case:
							panic("expected ',' or ')' in method argument list")
						}

						break
					}
				} else {
					next_token(tokenizer, arena) // consume )
				}

				node := new(ast.AST_Node, arena)
				node^ = ast.Method_Call {
					target = result,
					method = field_tok.content,
					args   = args_list,
				}

				result = node
				continue
			}

			// plain field access via expr.name
			node := new(ast.AST_Node, arena)
			node^ = ast.Field_Access {
				target = result,
				field  = field_tok.content,
			}

			result = node
			continue

		case tokens.Open_SB:
			next_token(tokenizer, arena) // consume [

			// forms
			// a[i]
			// a[:]
			// a[i:]
			// a[:j]
			// a[i:j]

			start: ^ast.AST_Node = nil
			end: ^ast.AST_Node = nil

			if _, has_colon_first := peek_token(tokenizer, arena).kind.(tokens.Colon); has_colon_first {
				next_token(tokenizer, arena) // consume :

				if _, closes := peek_token(tokenizer, arena).kind.(tokens.Close_SB); !closes {
					end = parse_expression(tokenizer, arena)
				}

				if _, ok := next_token(tokenizer, arena).kind.(tokens.Close_SB); !ok {
					panic("expected ']' after slice expression")
				}

				node := new(ast.AST_Node, arena)
				node^ = ast.Slice_Expr {
					target = result,
					start  = nil,
					end    = end,
				}

				result = node
				continue
			}

			// otherwise
			// a[i]
			// a[i:]
			// a[i:j]
			start = parse_expression(tokenizer, arena)

			if _, has_colon := peek_token(tokenizer, arena).kind.(tokens.Colon); has_colon {
				next_token(tokenizer, arena) // consume :

				if _, closes := peek_token(tokenizer, arena).kind.(tokens.Close_SB); !closes {
					end = parse_expression(tokenizer, arena)
				}

				if _, ok := next_token(tokenizer, arena).kind.(tokens.Close_SB); !ok {
					panic("expected ']' after slice expression")
				}

				node := new(ast.AST_Node, arena)
				node^ = ast.Slice_Expr {
					target = result,
					start  = start,
					end    = end,
				}

				result = node
				continue
			}

			if _, ok := next_token(tokenizer, arena).kind.(tokens.Close_SB); !ok {
				panic("expected ']' after index expression")
			}

			node := new(ast.AST_Node, arena)
			node^ = ast.Index_Expr {
				target = result,
				index  = start,
			}

			result = node
			continue

		case:
			return result
		}
	}

	return result
}
