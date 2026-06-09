package parser

import "ast"
import "base:runtime"
import "stack"
import "tokens"

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
		fn := parse_fn_signature(tokenizer, arena)

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
		structure := parse_struct_signature(tokenizer, arena)

		struct_node := new(ast.AST_Node, arena)
		struct_node^ = structure

		add_statement_to_block(current_scope, struct_node)

	case tokens.Trait:
		trait_decl := parse_trait_decl(tokenizer, arena)
		add_statement_to_block(current_scope, trait_decl)

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
	     tokens.Float_Literal,
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

	case tokens.Return:
		ret_node := new(ast.AST_Node, arena)
		expr: ^ast.AST_Node = nil

		// see if theres an expr following return
		next_tok := peek_token(tokenizer, arena)
		#partial switch _ in next_tok {
		case tokens.Semi_Colon, tokens.Close_Bracket, tokens.Eof:
		// remains nil
		case:
			// got an expression to evaluate
			expr = parse_expression(tokenizer, arena)
		}

		ret_node^ = ast.Return_Stmt {
			expr = expr,
		}

		add_statement_to_block(current_scope, ret_node)

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
	     tokens.Float_Literal,
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
