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

add_statement_to_block :: proc(block: ^ast.Block, statement: ^ast.AST_Node) {
	if block == nil || statement == nil {
		panic("nil block or statement")
	}
	append(block.items, statement)
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
