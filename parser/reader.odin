package parser

import "ast"
import "base:runtime"
import "core:mem/virtual"
import "core:os"

Parse_Result :: struct {
	root:      ^ast.AST_Node,
	ast_arena: virtual.Arena,
}

read_all :: proc(filepath: string, allocator: runtime.Allocator) -> ^Tokenizer {
	tokenizer := new_tokenizer(allocator)

	data, err := os.read_entire_file(filepath, allocator)
	if err != nil do panic("unable to read file")
	inject_src(tokenizer, string(data))

	return tokenizer
}

parse_file :: proc(filepath: string) -> Parse_Result {
	ast_arena: virtual.Arena
	_ = virtual.arena_init_growing(&ast_arena)
	ast_alloc := virtual.arena_allocator(&ast_arena)

	src_arena: virtual.Arena
	_ = virtual.arena_init_growing(&src_arena)
	src_alloc := virtual.arena_allocator(&src_arena)
	defer virtual.arena_destroy(&src_arena)

	tokenizer := read_all(filepath, src_alloc)
	root := parse_program(tokenizer, ast_alloc)

	free_all(context.temp_allocator)

	return Parse_Result{root = root, ast_arena = ast_arena}
}
