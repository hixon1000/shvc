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

package shiver

import "core:flags"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "parser"
import "parser/tokens"

Options :: struct {
	file:   string `args:"pos=0" usage:"The source file to process."`,
	ast:    bool `usage:"Print the AST."`,
	tokens: bool `usage:"Print the tokens."`,
}

main :: proc() {
	if len(os.args) == 1 {
		when ODIN_DEBUG {
			fmt.println("Shiver Compiler [DEBUG BUILD]")
		} else {
			fmt.println("Shiver Compiler")
		}
		fmt.println("Usage: ./shvc [flags] <filename>")
		fmt.println("Run './shvc -help' for a list of available options.")
		os.exit(0)
	}

	opt: Options

	flags.parse_or_exit(&opt, os.args, .Odin)

	if opt.file == "" {
		fmt.eprintln("Error: Missing file argument.")
		os.exit(1)
	}

	free_all(context.temp_allocator)
	context.allocator = mem.panic_allocator()

	if opt.tokens && !opt.ast {
		arena: virtual.Arena
		_ = virtual.arena_init_growing(&arena)
		alloc := virtual.arena_allocator(&arena)
		tokenizer := parser.read_all(opt.file, alloc)
		for {
			token := parser.next_token(tokenizer, alloc)
			fmt.println(token)
			if t, ok := token.kind.(tokens.Eof); ok {
				fmt.println(t)
				break
			}
		}
		virtual.arena_destroy(&arena)
	} else {
		program := parser.parse_file(opt.file)
		parser.debug_ast_print(program)
	}

	fmt.println("done")
}
