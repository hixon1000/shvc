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
	case tokens.Star:
		return 5
	}
	panic("precedence input token not an binary operator") // TODO: proper error handling
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
	return new_clone(node)
}

parse_expression :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	operator_stack := stack.make_stack(tokens.Token, context.temp_allocator)
	operand_stack := stack.make_stack(^ast.AST_Node, context.temp_allocator)

	outer: for {
		token := peek_token(tokenizer, context.temp_allocator)

		#partial switch _ in token {
		// hitting statmenet boundry
		case tokens.Semi_Colon, tokens.Close_Bracket, tokens.Open_Bracket:
			// very much needed as odin thinks break in switch is fallthrough breaker
			// but this one doesnt have fallthrough so we need to labeled break
			break outer
		}

		token = next_token(tokenizer, context.temp_allocator)

		#partial switch t in token {
		case tokens.Identifier, tokens.Int_Literal, tokens.String_Literal:
			stack.push(&operand_stack, create_leaf_node(token, arena))
		case tokens.Ampersand, tokens.Caret:
			// unary opts
			stack.push(&operator_stack, token)
		case tokens.Assign,
		     tokens.Plus,
		     tokens.Minus,
		     tokens.Star,
		     tokens.Equal,
		     tokens.Not_Equal,
		     tokens.Less,
		     tokens.Greater:
			// binary opts
			peeked_item, ok := stack.peek(&operator_stack) // TODO: handle peek failure
			for !stack.is_empty(&operator_stack) && precedence(peeked_item) >= precedence(token) {
				op, _ := stack.pop(&operator_stack) // TODO: error handling
				right, _ := stack.pop(&operand_stack) // TODO: error handling
				left, _ := stack.pop(&operand_stack)
				stack.push(
					&operand_stack,
					create_binary_node(left, op, right, context.temp_allocator),
				)
			}
			stack.push(&operator_stack, token)
		case tokens.Open_Paren:
			stack.push(&operator_stack, token)
		case tokens.Close_Paren:
			stack.push(&operator_stack, token)
		}
	}

	for !stack.is_empty(&operator_stack) {
		op, _ := stack.pop(&operator_stack) // TODO: error handling
		right, _ := stack.pop(&operand_stack)
		left, _ := stack.pop(&operand_stack)
		stack.push(&operand_stack, create_binary_node(left, op, right, context.temp_allocator))
	}

	result, _ := stack.pop(&operand_stack) // TODO: error handling

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

	// consume (
	next_token(tokenizer, arena) // TODO: error check

	// repeat until )
	for {
		// name
		arg_name, _ := next_token(tokenizer, arena).(tokens.Identifier)
		// :
		next_token(tokenizer, arena) // TODO: error check
		// type
		arg_type, _ := next_token(tokenizer, arena).(tokens.Identifier)
		// ,
		if next, ok := next_token(tokenizer, arena).(tokens.Comma); ok {
			continue
		}
		// close paren, break now
		if next, ok := next_token(tokenizer, arena).(tokens.Close_Paren); ok {
			break
		}
		panic("unexpected fn signiture") // TODO: handle error
	}

	return fn
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
	name, _ := next_token(tokenizer, arena).(tokens.Identifier)
	structure.name = name.content

	// consume {
	next_token(tokenizer, arena) // TODO: error check

	for {
		// fieldname
		field_name, _ := next_token(tokenizer, arena).(tokens.Identifier)
		// :
		next_token(tokenizer, arena) // TODO: error check
		// type
		arg_type, _ := next_token(tokenizer, arena).(tokens.Identifier)
		// ,
		if next, ok := next_token(tokenizer, arena).(tokens.Comma); ok {
			// allow for trailing comma
			if after, ok2 := peek_token(tokenizer, arena).(tokens.Close_Bracket); ok2 {
				break
			}
			continue
		}
		// or if you dont want to use trailing comma
		if next, ok := next_token(tokenizer, arena).(tokens.Close_Bracket); ok {
			break
		}
	}
	return structure
}

parse_var_decl :: proc(tokenizer: ^Tokenizer, arena: runtime.Arena) {


}


add_statement :: proc(parent: ^ast.AST_Node, statement: ^ast.AST_Node) {
	if parent == nil || statement == nil {
		panic("add_statement failure as parent or statement is nil")
	}

	#partial switch &p in parent {
	case ast.Program:
		append(p.statements.items, statement)
	case ast.Block:
		append(p.items, statement)
	case ast.For_Loop:
		append(p.body.items, statement)
	case ast.If_Stmt:
		append(p.body.items, statement)
	case:
		panic("attempt to add statement to non container code") // TODO: reconsider
	}

}

parse_program :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ast.AST_Node {
	dyn_arr_ptr := new([dynamic]^ast.AST_Node, arena)
	dyn_arr_ptr^ = make([dynamic]^ast.AST_Node, arena)
	root: ast.AST_Node = ast.Program {
		statements = ast.Block{dyn_arr_ptr},
	}

	scope_stack := stack.make_stack(^ast.AST_Node, context.temp_allocator)

	stack.push(&scope_stack, &root)

	for {
		token := next_token(tokenizer, arena)
		if _, ok := token.(tokens.Eof); ok {
			break
		}
		if _, ok := token.(tokens.Semi_Colon); ok {
			continue
		}

		current_scope, _ := stack.peek(&scope_stack)

		#partial switch t in token {
		case tokens.Fn:
			fn := parse_fn_signiture(tokenizer, arena)
			fn_wrap: ast.AST_Node = fn
			add_statement(current_scope, new_clone(fn_wrap, arena))
			stack.push(&scope_stack, new_clone(ast.AST_Node(fn.body), arena))
		case tokens.Struct:
			structure := parse_struct_signiture(tokenizer, arena)
			struct_wrap: ast.AST_Node = structure
			add_statement(current_scope, new_clone(struct_wrap, arena))
		case tokens.Val:


		case tokens.If:

		// case tokens.For:  // TODO: consider for loops

		case tokens.Open_Bracket:
			items_ptr := new([dynamic]^ast.AST_Node, arena)
			items_ptr^ = make([dynamic]^ast.AST_Node, arena)
			new_block: ast.AST_Node = ast.Block {
				items = items_ptr,
			}
			add_statement(current_scope, &new_block)

		case tokens.Close_Bracket:
			// arbitray on demand scope
			if scope_stack.len <= 1 {
				panic("unexpected closing bracket")
			}
			stack.pop(&scope_stack)
		case tokens.Identifier:
			unget_token(tokenizer, token) // put the whole token back
			expr := parse_expression(tokenizer, arena)
			add_statement(current_scope, expr)
		}
	}

	if scope_stack.len > 1 {
		panic("missing closing bracket")
	}

	return root

}
