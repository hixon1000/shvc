package parser

import "ast"
import "base:runtime"
import "stack"
import "tokens"

parse_expression :: proc(
	tokenizer: ^Tokenizer,
	arena: runtime.Allocator,
	allow_struct_literal: bool = true,
) -> ^ast.AST_Node {
	operator_stack := stack.make_stack(tokens.Token, context.temp_allocator)
	operand_stack := stack.make_stack(^ast.AST_Node, context.temp_allocator)

	open_paren_count := 0
	expecting_op := false // flag if we are in infix / postfix

	outer: for {
		token := peek_token(tokenizer, arena)

		#partial switch _ in token {
		case tokens.Semi_Colon, tokens.Close_Bracket, tokens.Comma, tokens.Close_SB:
			break outer

		case tokens.Open_Bracket:
			if expecting_op {
				// check if we are allowed to parse struct literals here
				if !allow_struct_literal {
					break outer
				}

				// typed literal found
				// eat {
				token = next_token(tokenizer, arena)

				// get type node that is just parsed
				type_node, ok := stack.pop(&operand_stack)
				if !ok do panic("compiler error: expecting_op true but operand stack empty")

				// parse content inside
				literal_node := parse_typed_braced_literal(tokenizer, arena, type_node)

				// back to the operand stack
				stack.push(&operand_stack, literal_node)
				expecting_op = true
				continue outer
			}

		case tokens.Close_Paren:
			if open_paren_count == 0 {
				break outer
			}
		}

		token = next_token(tokenizer, arena)

		#partial switch t in token {
		case tokens.Identifier:
			if expecting_op {
				// we have operand but we hit another identifier after
				// this means the expr ends
				unget_token(tokenizer, token)
				break outer
			}

			next := peek_token(tokenizer, arena)
			operand: ^ast.AST_Node

			if _, is_call := next.(tokens.Open_Paren); is_call {
				// eat the (
				next_token(tokenizer, arena)

				call_node := new(ast.AST_Node, arena)
				args_list := new([dynamic]^ast.AST_Node, arena)
				args_list^ = make([dynamic]^ast.AST_Node, arena)

				if _, empty := peek_token(tokenizer, arena).(tokens.Close_Paren); !empty {
					for {
						arg_expr := parse_expression(tokenizer, arena)
						append(args_list, arg_expr)

						sep := next_token(tokenizer, arena)
						#partial switch _ in sep {
						case tokens.Comma:
							continue
						case tokens.Close_Paren:
							break
						case:
							panic("expected ',' or ')' in argument list")
						}
						break
					}
				} else {
					next_token(tokenizer, arena)
				}

				call_node^ = ast.Call {
					target = create_leaf_node(token, arena),
					args   = args_list,
				}

				operand = call_node
			} else {
				operand = create_leaf_node(token, arena)
			}

			operand = parse_postfix_expr(tokenizer, arena, operand)

			stack.push(&operand_stack, operand)
			expecting_op = true

		case tokens.Int_Literal, tokens.Float_Literal, tokens.String_Literal:
			if expecting_op {
				unget_token(tokenizer, token)
				break outer
			}

			operand := create_leaf_node(token, arena)
			operand = parse_postfix_expr(tokenizer, arena, operand)

			stack.push(&operand_stack, operand)
			expecting_op = true

		case tokens.Ampersand, tokens.Caret:
			// unary opts
			if expecting_op {
				unget_token(tokenizer, token)
				break outer
			}
			stack.push(&operator_stack, token)

		case tokens.As, tokens.As_Bang:
			if !expecting_op {
				panic("unexpected cast operator without left-hand side expression")
			}

			// pop the lhs we casting rn
			left, ok := stack.pop(&operand_stack)
			if !ok do panic("missing left operand for cast")

			// we gotta see what type it is dont we
			target_type := parse_type(tokenizer, arena)

			_, is_reinterpret := token.(tokens.As_Bang)

			node := new(ast.AST_Node, arena)
			node^ = ast.Cast_Expr {
				expr           = left,
				target_type    = target_type,
				is_reinterpret = is_reinterpret,
			}

			stack.push(&operand_stack, node)
			expecting_op = true // cast expression acts as a completed operand phrase

		// expecting_op remains false here cuz unary ops
		case tokens.Assign,
		     tokens.Plus_Assign,
		     tokens.Minus_Assign,
		     tokens.Plus,
		     tokens.Minus,
		     tokens.Star,
		     tokens.Slash,
		     tokens.Equal,
		     tokens.Not_Equal,
		     tokens.Less,
		     tokens.Greater:
			// binary opts
			if !expecting_op {
				panic("unexpected binary operator")
			}

			for !stack.is_empty(&operator_stack) {
				top, _ := stack.peek(&operator_stack)

				if _, ok := top.(tokens.Open_Paren); ok {
					break
				}

				top_prec := precedence(top)
				cur_prec := precedence(token)

				if top_prec > cur_prec || (!is_right_assoc(token) && top_prec == cur_prec) {
					apply_operator(&operator_stack, &operand_stack, arena)
					continue
				}

				break
			}

			stack.push(&operator_stack, token)
			expecting_op = false

		case tokens.Open_Paren:
			if expecting_op {
				unget_token(tokenizer, token)
				break outer
			}
			open_paren_count += 1
			stack.push(&operator_stack, token)

		case tokens.Close_Paren:
			if !expecting_op {
				panic("unexpected ')'")
			}
			open_paren_count -= 1
			found_open := false

			for !stack.is_empty(&operator_stack) {
				top, _ := stack.peek(&operator_stack)

				if _, ok := top.(tokens.Open_Paren); ok {
					stack.pop(&operator_stack)
					found_open = true
					break
				}

				apply_operator(&operator_stack, &operand_stack, arena)
			}

			if !found_open {
				panic("unmatched closing parenthesis")
			}
			expecting_op = true // closed paren acts like a completed operand

		case tokens.Open_Bracket:
			if expecting_op {
				unget_token(tokenizer, token)
				break outer
			}

			operand := parse_braced_literal(tokenizer, arena)
			operand = parse_postfix_expr(tokenizer, arena, operand)

			stack.push(&operand_stack, operand)
			expecting_op = true

		case:
			// if we see keywords or tokens we have no idea what it is
			// we should stop parsing now
			unget_token(tokenizer, token)
			break outer
		}
	}

	for !stack.is_empty(&operator_stack) {
		top, _ := stack.peek(&operator_stack)

		if _, ok := top.(tokens.Open_Paren); ok {
			panic("unmatched parenthesis")
		}
		if _, ok := top.(tokens.Close_Paren); ok {
			panic("unmatched parenthesis")
		}

		apply_operator(&operator_stack, &operand_stack, arena)
	}

	result, ok := stack.pop(&operand_stack)
	if !ok {
		panic("expected expression")
	}

	if !stack.is_empty(&operand_stack) {
		panic("malformed expression: too many operands")
	}

	return result
}
