package shiver

import "core:fmt"
import "core:mem"
import "core:os"
import "parser"

main :: proc() {
	context.allocator = mem.panic_allocator()

	file := os.args[1]

	program := parser.parse_file(file)
	parser.debug_ast_print(program)

	fmt.println("done")
}
