package parser

import "ast"
import "base:runtime"
import "stack"

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
