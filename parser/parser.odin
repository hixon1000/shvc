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

import "ast"
import "base:runtime"
import "stack"
import "tokens"

parse_program :: proc(tokenizer: ^Tokenizer, arena: runtime.Allocator) -> ^ast.Spanned_AST {
	scope_stack := stack.make_stack(^ast.Block, context.temp_allocator)

	root_block := make_block(arena)

	root := new(ast.Spanned_AST, arena)
	root.kind = ast.Program {
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

	root.span = tokens.Span{start = 0, end = tokenizer.cursor}
	return root
}
