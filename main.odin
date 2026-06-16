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
