package parser

import "ast"
import "base:runtime"
import "core:fmt"
import types "stock_types"
import "tokens"

// name ( args ) -> type
// args as in name : type , name : type , ...
parse_fn_signature :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ast.Fn_Decl {
	fn := ast.Fn_Decl{}
	args_ptr := new([dynamic]ast.Type_Pair, arena)
	args_ptr^ = make([dynamic]ast.Type_Pair, arena)
	fn.args = args_ptr
	fn.body = make_block(arena)

	first_tok, idok := next_token(tokenizer, arena).kind.(tokens.Identifier)
	if !idok do panic("expected function or method name")

	if _, has_dot := peek_token(tokenizer, arena).kind.(tokens.Dot); has_dot {
		next_token(tokenizer, arena) // consume .
		method_tok, mok := next_token(tokenizer, arena).kind.(tokens.Identifier)
		if !mok do panic("expected method name after '.'")

		// combine them into a single string identifier
		// this sound like a bandaid solution
		// TODO: reconsider
		fn.name = fmt.aprintf("%s.%s", first_tok.content, method_tok.content, allocator = arena)
	} else {
		fn.name = first_tok.content
	}

	// consume (
	if _, ntok := next_token(tokenizer, arena).kind.(tokens.Open_Paren); !ntok {
		panic("expected '('")
	}

	if _, ptok := peek_token(tokenizer, arena).kind.(tokens.Close_Paren); ptok {
		next_token(tokenizer, arena)
	} else {
		arg_loop: for {
			// handle mut prefix
			tok := next_token(tokenizer, arena)
			is_arg_mut := false
			if _, is_mut := tok.kind.(tokens.Mut); is_mut {
				is_arg_mut = true
				tok = next_token(tokenizer, arena)
			}

			arg_name_tok, name_ok := tok.kind.(tokens.Identifier)
			if !name_ok do panic("expected argument name")

			if _, colok := next_token(tokenizer, arena).kind.(tokens.Colon); !colok {
				panic("expected ':'")
			}

			arg_type := parse_type(tokenizer, arena)

			append(
				fn.args,
				ast.Type_Pair{name = arg_name_tok.content, type = arg_type, is_mut = is_arg_mut},
			)

			sep := next_token(tokenizer, arena)
			#partial switch _ in sep.kind {
			case tokens.Comma:
				continue
			case tokens.Close_Paren:
				break arg_loop
			case:
				panic("expected ',' or ')'")
			}
		}
	}

	fn.ret_type = types.Unit{}

	if _, arok := peek_token(tokenizer, arena).kind.(tokens.Arrow); arok {
		next_token(tokenizer, arena) // consume ->
		fn.ret_type = parse_type(tokenizer, arena)
	}

	return fn
}

parse_trait_decl :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	name_tok, idok := next_token(tokenizer, arena).kind.(tokens.Identifier)
	if !idok do panic("expected trait name")

	if _, obok := next_token(tokenizer, arena).kind.(tokens.Open_Bracket); !obok {
		panic("expected '{' after trait name")
	}

	methods_ptr := new([dynamic]ast.Fn_Decl, arena)
	methods_ptr^ = make([dynamic]ast.Fn_Decl, arena)

	for {
		if _, cbok := peek_token(tokenizer, arena).kind.(tokens.Close_Bracket); cbok {
			next_token(tokenizer, arena) // consume }
			break
		}

		tok := next_token(tokenizer, arena)

		#partial switch _ in tok.kind {
		case tokens.Fn:
			method_sig := parse_fn_signature(tokenizer, arena)
			append(methods_ptr, method_sig)

		case tokens.Semi_Colon:
			continue

		case:
			panic("expected method declaration or '}' inside trait body")
		}
	}

	node := new(ast.AST_Node, arena)
	node^ = ast.Trait_Decl {
		name    = name_tok.content,
		methods = methods_ptr,
	}

	return node
}

// name { fieldname : type , fieldname : type , }
// optional trailing comma
parse_struct_signature :: proc(
	tokenizer: ^Tokenizer,
	arena: runtime.Allocator,
) -> ast.Struct_Decl {
	structure := ast.Struct_Decl{}

	fields_ptr := new([dynamic]ast.Type_Pair, arena)
	fields_ptr^ = make([dynamic]ast.Type_Pair, arena)
	structure.fields = fields_ptr

	name_tok, idok := next_token(tokenizer, arena).kind.(tokens.Identifier)
	if !idok do panic("expected struct name")

	structure.name = name_tok.content

	if _, obok := next_token(tokenizer, arena).kind.(tokens.Open_Bracket); !obok {
		panic("expected '{'")
	}

	for {
		if _, cbok := peek_token(tokenizer, arena).kind.(tokens.Close_Bracket); cbok {
			next_token(tokenizer, arena)
			break
		}
		if _, cpok := peek_token(tokenizer, arena).kind.(tokens.Close_Paren); cpok {
			next_token(tokenizer, arena)
			break
		}

		field_name_tok, fidok := next_token(tokenizer, arena).kind.(tokens.Identifier)
		if !fidok do panic("expected field name")

		if _, ok := next_token(tokenizer, arena).kind.(tokens.Colon); !ok {
			panic("expected ':'")
		}

		field_type_tok, fok := next_token(tokenizer, arena).kind.(tokens.Identifier)
		if !fok do panic("expected field type")

		append(
			structure.fields,
			ast.Type_Pair {
				name = field_name_tok.content,
				type = parse_type_from_identifier(field_type_tok.content),
			},
		)

		sep := next_token(tokenizer, arena)

		#partial switch _ in sep.kind {
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

parse_var_decl :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.AST_Node {
	token := next_token(tokenizer, arena)
	is_mutable := false

	// check if its mut
	if _, ok := token.kind.(tokens.Mut); ok {
		is_mutable = true
		token = next_token(tokenizer, arena)
	}

	// next token is val
	if _, ok := token.kind.(tokens.Val); !ok {
		panic("expected 'val' keyword in variable declaration")
	}

	// grab the var name
	name_tok, varnameok := next_token(tokenizer, arena).kind.(tokens.Identifier)
	if !varnameok do panic("expected variable name identifier")

	// a : for type
	if _, colok := next_token(tokenizer, arena).kind.(tokens.Colon); !colok {
		panic("expected ':' after variable name")
	}

	// type parsing
	var_type := parse_type(tokenizer, arena)

	// optional init
	init_kind := ast.Var_Init_Kind.Zero
	value_expr: ^ast.AST_Node = nil

	if _, has_assign := peek_token(tokenizer, arena).kind.(tokens.Assign); has_assign {
		next_token(tokenizer, arena) // consume =

		if _, is_question := peek_token(tokenizer, arena).kind.(tokens.Question); is_question {
			next_token(tokenizer, arena) // consume ?
			init_kind = .Undef
		} else {
			value_expr = parse_expression(tokenizer, arena)
			init_kind = .Expr
		}
	}

	// make node
	node := new(ast.AST_Node, arena)
	node^ = ast.Var_Decl {
		name      = name_tok.content,
		type_info = var_type,
		is_mut    = is_mutable,
		init_kind = init_kind,
		init_expr = value_expr,
	}

	return node
}
