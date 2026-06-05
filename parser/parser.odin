package parser

import "ast"
import "base:runtime"
import "core:fmt"
import "stack"
import types "stock_types"
import "tokens"

precedence :: proc(token: tokens.Token) -> u8 {
	#partial switch _ in token {
	case tokens.Assign:
		return 1
	case tokens.Equal, tokens.Not_Equal:
		return 2
	case tokens.Less, tokens.Greater:
		return 3
	case tokens.Plus, tokens.Minus:
		return 4
	case tokens.Star, tokens.Slash:
		return 5
	case tokens.Ampersand, tokens.Caret:
		return 6
	}
	panic("precedence input token not an operator") // TODO: proper error handling
}

create_leaf_node :: proc(token: tokens.Token, alloc: runtime.Allocator) -> ^ast.AST_Node {
	// alloc should be the arena
	node := new(ast.AST_Node, alloc)
	#partial switch t in token {
	case tokens.Identifier:
		node^ = ast.Identifier {
			name = t.content,
		}
		return node
	case tokens.Int_Literal:
		node^ = ast.Literal { 	// TODO: separate Int and String literal
			type  = types.Integer64{},
			value = fmt.aprintf("%d", t.content, alloc),
		}
		return node
	case tokens.String_Literal:
		node^ = ast.Literal {
			type  = types.String{},
			value = t.content,
		}
		return node
	case:
		panic("excepted an identifier or literal")
	}
}

create_binary_node :: proc(
	left: ^ast.AST_Node,
	op: tokens.Token,
	right: ^ast.AST_Node,
	arena: runtime.Allocator,
) -> ^ast.AST_Node { 	// do this even need allocation
	node: ast.AST_Node = ast.Binary_Op {
		left  = left,
		op    = op,
		right = right,
	}
	return new_clone(node, arena)
}

create_unary_node :: proc(
	op: tokens.Token,
	operand: ^ast.AST_Node,
	arena: runtime.Allocator,
) -> ^ast.AST_Node {
	node := new(ast.AST_Node, arena)
	node^ = ast.Unary_Op {
		op      = op,
		operand = operand,
	}
	return node
}

apply_operator :: proc(
	operator_stack: ^stack.Stack(tokens.Token),
	operand_stack: ^stack.Stack(^ast.AST_Node),
	arena: runtime.Allocator,
) {
	op, ok := stack.pop(operator_stack)
	if !ok {
		panic("missing operator")
	}

	if is_unary(op) {
		operand, ok := stack.pop(operand_stack)
		if !ok {
			panic("missing unary operand")
		}

		stack.push(operand_stack, create_unary_node(op, operand, arena))
		return
	}

	right, rok := stack.pop(operand_stack)
	left, lok := stack.pop(operand_stack)

	if !rok || !lok {
		panic("missing binary operand")
	}

	stack.push(operand_stack, create_binary_node(left, op, right, arena))
}


is_right_assoc :: proc(token: tokens.Token) -> bool {
	#partial switch _ in token {
	case tokens.Assign:
		return true
	}
	return false
}

is_unary :: proc(token: tokens.Token) -> bool {
	#partial switch _ in token {
	case tokens.Ampersand, tokens.Caret:
		return true
	}
	return false
}

make_block :: proc(arena: runtime.Allocator) -> ^ast.Block {
	items_ptr := new([dynamic]^ast.AST_Node, arena)
	items_ptr^ = make([dynamic]^ast.AST_Node, arena)

	block := new(ast.Block, arena)
	block^ = ast.Block {
		items = items_ptr,
	}

	return block
}

make_block_node :: proc(block: ^ast.Block, arena: runtime.Allocator) -> ^ast.AST_Node {
	node := new(ast.AST_Node, arena)
	node^ = block^
	return node
}

parse_expression :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	operator_stack := stack.make_stack(tokens.Token, context.temp_allocator)
	operand_stack := stack.make_stack(^ast.AST_Node, context.temp_allocator)

	open_paren_count := 0

	outer: for {
		token := peek_token(tokenizer, arena)

		#partial switch _ in token {
		// hitting statmenet boundry
		case tokens.Semi_Colon, tokens.Close_Bracket, tokens.Open_Bracket, tokens.Comma:
			// very much needed as odin thinks break in switch is fallthrough breaker
			// but this one doesnt have fallthrough so we need to labeled break
			break outer
		case tokens.Close_Paren:
			if open_paren_count == 0 {
				break outer
			}
		}

		token = next_token(tokenizer, arena)

		#partial switch t in token {
		case tokens.Identifier:
			next := peek_token(tokenizer, arena)
			if _, is_call := next.(tokens.Open_Paren); is_call {
				// eat the (
				next_token(tokenizer, arena)

				call_node := new(ast.AST_Node, arena)
				args_list := new([dynamic]^ast.AST_Node, arena)
				args_list^ = make([dynamic]^ast.AST_Node, arena)

				// loop and parse , args until hitting close paren
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
					next_token(tokenizer, arena) // consume empty )
				}

				call_node^ = ast.Call {
					target = create_leaf_node(token, arena), // token is the identifier
					args   = args_list,
				}
				stack.push(&operand_stack, call_node)
			} else {
				stack.push(&operand_stack, create_leaf_node(token, arena))
			}

		case tokens.Int_Literal, tokens.String_Literal:
			stack.push(&operand_stack, create_leaf_node(token, arena))
		case tokens.Ampersand, tokens.Caret:
			// unary opts
			stack.push(&operator_stack, token)
		case tokens.Assign,
		     tokens.Plus,
		     tokens.Minus,
		     tokens.Star,
		     tokens.Slash,
		     tokens.Equal,
		     tokens.Not_Equal,
		     tokens.Less,
		     tokens.Greater:
			// binary opts
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
		case tokens.Open_Paren:
			open_paren_count += 1
			stack.push(&operator_stack, token)

		case tokens.Close_Paren:
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

// name ( args ) -> type
// args as in name : type , name : type , ...
parse_fn_signiture :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ast.Fn_Decl {
	fn := ast.Fn_Decl{}
	args_ptr := new([dynamic]ast.Type_Pair, arena)
	args_ptr^ = make([dynamic]ast.Type_Pair, arena)
	fn.args = args_ptr
	name, _ := next_token(tokenizer, arena).(tokens.Identifier)
	fn.name = name.content
	fn.body = make_block(arena)

	// consume (
	if _, ok := next_token(tokenizer, arena).(tokens.Open_Paren); !ok {
		panic("expected '('")
	}

	if _, ok := peek_token(tokenizer, arena).(tokens.Close_Paren); ok {
		next_token(tokenizer, arena)
	} else {
		for {
			arg_name_tok, ok := next_token(tokenizer, arena).(tokens.Identifier)
			if !ok do panic("expected argument name")

			if _, ok := next_token(tokenizer, arena).(tokens.Colon); !ok {
				panic("expected ':'")
			}

			arg_type_tok, nok := next_token(tokenizer, arena).(tokens.Identifier)
			if !nok do panic("expected argument type")

			append(
				fn.args,
				ast.Type_Pair {
					name = arg_name_tok.content,
					type = parse_type_from_identifier(arg_type_tok.content),
				},
			)

			sep := next_token(tokenizer, arena)

			#partial switch _ in sep {
			case tokens.Comma:
				continue
			case tokens.Close_Paren:
				break
			case:
				panic("expected ',' or ')'")
			}
		}
	}

	fn.ret_type = types.Unit{}

	if _, ok := peek_token(tokenizer, arena).(tokens.Arrow); ok {
		next_token(tokenizer, arena)

		ret_tok, ok := next_token(tokenizer, arena).(tokens.Identifier)
		if !ok do panic("expected return type")

		fn.ret_type = parse_type_from_identifier(ret_tok.content)
	}

	return fn
}

parse_type_from_identifier :: proc(name: string) -> types.Types {
	switch name {
	case "unit":
		return types.Unit{}
	case "int":
		return types.Integer{}
	case "i8":
		return types.Integer8{}
	case "i32":
		return types.Integer32{}
	case "i64":
		return types.Integer64{}
	case "string":
		return types.String{}
	}

	panic("unknown type")
}


// name { fieldname : type , fieldname : type , }
// optional trailing comma
parse_struct_signiture :: proc(
	tokenizer: ^Tokenizer,
	arena: runtime.Allocator,
) -> ast.Struct_Decl {
	structure := ast.Struct_Decl{}

	fields_ptr := new([dynamic]ast.Type_Pair, arena)
	fields_ptr^ = make([dynamic]ast.Type_Pair, arena)
	structure.fields = fields_ptr

	name_tok, ok := next_token(tokenizer, arena).(tokens.Identifier)
	if !ok do panic("expected struct name")

	structure.name = name_tok.content

	if _, ok := next_token(tokenizer, arena).(tokens.Open_Bracket); !ok {
		panic("expected '{'")
	}

	for {
		if _, ok := peek_token(tokenizer, arena).(tokens.Close_Bracket); ok {
			next_token(tokenizer, arena)
			break
		}
		if _, ok := peek_token(tokenizer, arena).(tokens.Close_Paren); ok {
			next_token(tokenizer, arena)
			break
		}

		field_name_tok, ok := next_token(tokenizer, arena).(tokens.Identifier)
		if !ok do panic("expected field name")

		if _, ok := next_token(tokenizer, arena).(tokens.Colon); !ok {
			panic("expected ':'")
		}

		field_type_tok, fok := next_token(tokenizer, arena).(tokens.Identifier)
		if !fok do panic("expected field type")

		append(
			structure.fields,
			ast.Type_Pair {
				name = field_name_tok.content,
				type = parse_type_from_identifier(field_type_tok.content),
			},
		)

		sep := next_token(tokenizer, arena)

		#partial switch _ in sep {
		case tokens.Comma:
			continue
		case tokens.Close_Bracket:
			break
		case:
			panic("expected ',' or '}'")
		}
	}

	return structure
}

parse_var_decl :: proc(tokenizer: ^Tokenizer, arena: runtime.Arena) {


}

add_statement_to_block :: proc(block: ^ast.Block, statement: ^ast.AST_Node) {
	if block == nil || statement == nil {
		panic("nil block or statement")
	}
	append(block.items, statement)
}


parse_program :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	scope_stack := stack.make_stack(^ast.Block, context.temp_allocator)

	root_block := make_block(arena)

	root := new(ast.AST_Node, arena)
	root^ = ast.Program {
		statements = root_block^,
	}

	stack.push(&scope_stack, root_block)

	for {
		token := next_token(tokenizer, arena)

		if _, ok := token.(tokens.Eof); ok {
			break
		}

		if _, ok := token.(tokens.Semi_Colon); ok {
			continue
		}

		current_scope, ok := stack.peek(&scope_stack)
		if !ok {
			panic("internal parser error: empty scope stack")
		}

		#partial switch _ in token {
		case tokens.Fn:
			fn := parse_fn_signiture(tokenizer, arena)

			fn_node := new(ast.AST_Node, arena)
			fn_node^ = fn

			add_statement_to_block(current_scope, fn_node)

			if _, ok := peek_token(tokenizer, arena).(tokens.Open_Bracket); ok {
				next_token(tokenizer, arena)
				stack.push(&scope_stack, fn.body)
			} else {
				panic("expected function body")
			}

		case tokens.Struct:
			structure := parse_struct_signiture(tokenizer, arena)

			struct_node := new(ast.AST_Node, arena)
			struct_node^ = structure

			add_statement_to_block(current_scope, struct_node)

		case tokens.Open_Bracket:
			new_block := make_block(arena)
			block_node := make_block_node(new_block, arena)

			add_statement_to_block(current_scope, block_node)
			stack.push(&scope_stack, new_block)

		case tokens.Close_Bracket:
			if scope_stack.len <= 1 {
				panic("unexpected closing bracket")
			}
			stack.pop(&scope_stack)

		case tokens.Identifier,
		     tokens.Int_Literal,
		     tokens.String_Literal,
		     tokens.Open_Paren,
		     tokens.Ampersand,
		     tokens.Caret:
			unget_token(tokenizer, token)
			expr := parse_expression(tokenizer, arena)
			add_statement_to_block(current_scope, expr)

		case tokens.Val:
			panic("var declarations not implemented")

		case tokens.If:
			panic("if statements not implemented")

		case:
			panic("unexpected token at statement level")
		}
	}

	if scope_stack.len > 1 {
		panic("missing closing bracket")
	}

	return root
}
