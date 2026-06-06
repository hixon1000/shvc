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
			value = fmt.aprintf("%d", t.content, allocator = alloc),
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
	op, ostack_ok := stack.pop(operator_stack)
	if !ostack_ok {
		panic("missing operator")
	}

	if is_unary(op) {
		operand, ostack_u_ok := stack.pop(operand_stack)
		if !ostack_u_ok {
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

Parse_Status :: enum {
	Continue,
	Done,
}

parse_statement_into_current_scope :: proc(
	tokenizer: ^Tokenizer,
	arena: runtime.Allocator,
	scope_stack: ^stack.Stack(^ast.Block),
	is_root: bool,
) -> Parse_Status {
	token := next_token(tokenizer, arena)

	if _, eofok := token.(tokens.Eof); eofok {
		if !is_root {
			panic("unexpected EOF inside block")
		}

		return .Done
	}

	if _, scok := token.(tokens.Semi_Colon); scok {
		return .Continue
	}

	current_scope, stackok := stack.peek(scope_stack)
	if !stackok {
		panic("internal parser error: empty scope stack")
	}

	#partial switch _ in token {
	case tokens.Fn:
		fn := parse_fn_signiture(tokenizer, arena)

		fn_node := new(ast.AST_Node, arena)
		fn_node^ = fn

		add_statement_to_block(current_scope, fn_node)

		if _, obok := peek_token(tokenizer, arena).(tokens.Open_Bracket); obok {
			next_token(tokenizer, arena)
			stack.push(scope_stack, fn.body)
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
		stack.push(scope_stack, new_block)

	case tokens.Close_Bracket:
		if scope_stack.len <= 1 {
			if is_root {
				panic("unexpected closing bracket")
			}

			stack.pop(scope_stack)
			return .Done
		}

		stack.pop(scope_stack)

	case tokens.Identifier,
	     tokens.Int_Literal,
	     tokens.String_Literal,
	     tokens.Open_Paren,
	     tokens.Ampersand,
	     tokens.Caret:
		unget_token(tokenizer, token)
		expr := parse_expression(tokenizer, arena)
		add_statement_to_block(current_scope, expr)

	case tokens.Val, tokens.Mut:
		unget_token(tokenizer, token)
		var_node := parse_var_decl(tokenizer, arena)
		add_statement_to_block(current_scope, var_node)

	case tokens.Defer:
		defer_node := new(ast.AST_Node, arena)

		if _, is_block := peek_token(tokenizer, arena).(tokens.Open_Bracket); is_block {
			next_token(tokenizer, arena)

			defer_block := make_block(arena)

			defer_node^ = ast.Defer_Stmt {
				stmt = make_block_node(defer_block, arena),
			}

			add_statement_to_block(current_scope, defer_node)

			stack.push(scope_stack, defer_block)
		} else {
			expr := parse_expression(tokenizer, arena)

			defer_node^ = ast.Defer_Stmt {
				stmt = expr,
			}

			add_statement_to_block(current_scope, defer_node)
		}

	case tokens.If:
		if_node := parse_if_statement(tokenizer, arena)
		add_statement_to_block(current_scope, if_node)

	case:
		panic("unexpected token at statement level")
	}

	return .Continue
}


parse_single_statement_after_do :: proc(
	tokenizer: ^Tokenizer,
	arena: runtime.Allocator,
) -> ^ast.AST_Node {
	token := next_token(tokenizer, arena)

	#partial switch _ in token {
	case tokens.Identifier,
	     tokens.Int_Literal,
	     tokens.String_Literal,
	     tokens.Open_Paren,
	     tokens.Ampersand,
	     tokens.Caret:
		unget_token(tokenizer, token)
		return parse_expression(tokenizer, arena)

	case tokens.Val, tokens.Mut:
		unget_token(tokenizer, token)
		return parse_var_decl(tokenizer, arena)

	case tokens.Defer:
		defer_node := new(ast.AST_Node, arena)

		if _, is_block := peek_token(tokenizer, arena).(tokens.Open_Bracket); is_block {
			panic("block defer is not allowed after 'do'; use 'if cond { defer { ... } }'")
		}

		expr := parse_expression(tokenizer, arena)

		defer_node^ = ast.Defer_Stmt {
			stmt = expr,
		}

		return defer_node

	case:
		panic("expected statement after do")
	}

	panic("unreachable") // im going to crash out if we hit this
}

parse_if_body :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	next := next_token(tokenizer, arena)

	#partial switch _ in next {
	case tokens.Open_Bracket:
		return parse_block_body(tokenizer, arena)

	case tokens.Do:
		return parse_single_statement_after_do(tokenizer, arena)

	case:
		panic("expected '{' or 'do' after if condition")
	}

	panic("unreachable")
}

parse_if_statement :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	conditions := make([dynamic]^ast.AST_Node, arena)
	bodies := make([dynamic]^ast.AST_Node, arena)

	final_else: ^ast.AST_Node = nil

	// parse first if
	first_cond := parse_expression(tokenizer, arena)
	first_body := parse_if_body(tokenizer, arena)

	append(&conditions, first_cond)
	append(&bodies, first_body)

	// parse 0 or more else ifs, then else
	for {
		if _, has_else := peek_token(tokenizer, arena).(tokens.Else); !has_else {
			break
		}

		// consume else
		next_token(tokenizer, arena)

		if _, has_if := peek_token(tokenizer, arena).(tokens.If); has_if {
			// consume if
			next_token(tokenizer, arena)

			cond := parse_expression(tokenizer, arena)
			body := parse_if_body(tokenizer, arena)

			append(&conditions, cond)
			append(&bodies, body)

			continue
		}

		// plain else
		next := next_token(tokenizer, arena)

		#partial switch _ in next {
		case tokens.Open_Bracket:
			final_else = parse_block_body(tokenizer, arena)

		case tokens.Do:
			final_else = parse_single_statement_after_do(tokenizer, arena)

		case:
			panic("expected '{', 'do', or 'if' after 'else'")
		}

		break
	}

	// build if statement
	tail := final_else

	for i := len(conditions) - 1; i >= 0; i -= 1 {
		node := new(ast.AST_Node, arena)

		node^ = ast.If_Stmt {
			condition = conditions[i],
			body      = bodies[i],
			else_stmt = tail,
		}

		tail = node

		if i == 0 {
			break
		}
	}

	return tail
}


parse_block_body :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	scope_stack := stack.make_stack(^ast.Block, context.temp_allocator)

	root_block := make_block(arena)
	stack.push(&scope_stack, root_block)

	for {
		status := parse_statement_into_current_scope(tokenizer, arena, &scope_stack, false)

		if status == .Done {
			break
		}
	}

	if scope_stack.len != 0 {
		panic("internal parser error: block parser ended with non-empty scope stack")
	}

	return make_block_node(root_block, arena)
}


parse_expression :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	operator_stack := stack.make_stack(tokens.Token, context.temp_allocator)
	operand_stack := stack.make_stack(^ast.AST_Node, context.temp_allocator)

	open_paren_count := 0
	expecting_op := false // flag if we are in infix / postfix

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
			if expecting_op {
				// we have operand but we hit another identifier after
				// this means the expr ends
				unget_token(tokenizer, token)
				break outer
			}

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
			expecting_op = true

		case tokens.Int_Literal, tokens.String_Literal:
			if expecting_op {
				unget_token(tokenizer, token)
				break outer
			}
			stack.push(&operand_stack, create_leaf_node(token, arena))
			expecting_op = true
		case tokens.Ampersand, tokens.Caret:
			// unary opts
			if expecting_op {
				unget_token(tokenizer, token)
				break outer
			}
			stack.push(&operator_stack, token)
		// expecting_op remains false here cuz unary ops
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
	if _, ntok := next_token(tokenizer, arena).(tokens.Open_Paren); !ntok {
		panic("expected '('")
	}

	if _, ptok := peek_token(tokenizer, arena).(tokens.Close_Paren); ptok {
		next_token(tokenizer, arena)
	} else {
		for {
			arg_name_tok, idok := next_token(tokenizer, arena).(tokens.Identifier)
			if !idok do panic("expected argument name")

			if _, colok := next_token(tokenizer, arena).(tokens.Colon); !colok {
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

	if _, arok := peek_token(tokenizer, arena).(tokens.Arrow); arok {
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

	name_tok, idok := next_token(tokenizer, arena).(tokens.Identifier)
	if !idok do panic("expected struct name")

	structure.name = name_tok.content

	if _, obok := next_token(tokenizer, arena).(tokens.Open_Bracket); !obok {
		panic("expected '{'")
	}

	for {
		if _, cbok := peek_token(tokenizer, arena).(tokens.Close_Bracket); cbok {
			next_token(tokenizer, arena)
			break
		}
		if _, cpok := peek_token(tokenizer, arena).(tokens.Close_Paren); cpok {
			next_token(tokenizer, arena)
			break
		}

		field_name_tok, fidok := next_token(tokenizer, arena).(tokens.Identifier)
		if !fidok do panic("expected field name")

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

parse_type :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> types.Types {
	token := next_token(tokenizer, arena)

	#partial switch t in token {
	case tokens.Caret:
		elem_type := parse_type(tokenizer, arena)
		return types.Pointer{elem = new_clone(elem_type, arena)}

	case tokens.Identifier:
		return parse_type_from_identifier(t.content)

	case:
		panic("expected a valid type identifier or type modifier")
	}
}

parse_var_decl :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	token := next_token(tokenizer, arena)
	is_mutable := false

	// check if its mut
	if _, ok := token.(tokens.Mut); ok {
		is_mutable = true
		token = next_token(tokenizer, arena)
	}

	// next token is val
	if _, ok := token.(tokens.Val); !ok {
		panic("expected 'val' keyword in variable declaration")
	}

	// grab the var name
	name_tok, varnameok := next_token(tokenizer, arena).(tokens.Identifier)
	if !varnameok do panic("expected variable name identifier")

	// a : for type
	if _, colok := next_token(tokenizer, arena).(tokens.Colon); !colok {
		panic("expected ':' after variable name")
	}

	// type parsing
	var_type := parse_type(tokenizer, arena)

	// expect a =
	if _, ok := next_token(tokenizer, arena).(tokens.Assign); !ok {
		panic("expected '=' after type specification")
	}

	// parse assignment
	value_expr := parse_expression(tokenizer, arena)

	// make node
	node := new(ast.AST_Node, arena)
	node^ = ast.Var_Decl {
		name      = name_tok.content,
		type_info = var_type,
		is_mut    = is_mutable,
		init_expr = value_expr,
	}

	return node
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
		status := parse_statement_into_current_scope(tokenizer, arena, &scope_stack, true)

		if status == .Done {
			break
		}
	}

	if scope_stack.len > 1 {
		panic("missing closing bracket")
	}

	return root
}
