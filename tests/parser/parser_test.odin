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

package parser_test

import "../../parser"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:strings"
import "core:testing"

LARGE_SRC_PATH :: "tests/parser/fixtures/main.shv"
EXPECTED_AST :: #load("fixtures/main.shv.ast", string)

@(test)
test_large_program_ast_generation :: proc(t: ^testing.T) {
	arena: virtual.Arena
	_ = virtual.arena_init_growing(&arena)
	alloc := virtual.arena_allocator(&arena)
	defer virtual.arena_destroy(&arena)

	result := parser.parse_file(LARGE_SRC_PATH)
	defer virtual.arena_destroy(&result.ast_arena)

	actual_ast_raw := parser.debug_ast_dump(result, alloc)

	actual_clean, _ := strings.replace_all(actual_ast_raw, "\r\n", "\n", alloc)
	expected_clean, _ := strings.replace_all(EXPECTED_AST, "\r\n", "\n", alloc)

	actual_lines := strings.split_lines(strings.trim_space(actual_clean), alloc)
	expected_lines := strings.split_lines(strings.trim_space(expected_clean), alloc)

	mismatch := false
	max_lines := max(len(expected_lines), len(actual_lines))

	for i := 0; i < max_lines; i += 1 {
		exp := i < len(expected_lines) ? expected_lines[i] : "<END OF TREE>"
		act := i < len(actual_lines) ? actual_lines[i] : "<END OF TREE>"
		if exp != act {
			mismatch = true
			break
		}
	}

	if mismatch {
		log.error("\n=== AST STRUCTURAL MISMATCH DETECTED ===\n")
		log.errorf(
			"%-4s | %-50s | %-50s\n",
			"Line",
			"Expected Snapshot",
			"Actual Tree Node Output",
		)
		log.errorf(
			"-------------------------------------------------------------------------------------------------------\n",
		)

		for i := 0; i < max_lines; i += 1 {
			exp := i < len(expected_lines) ? expected_lines[i] : "<END OF TREE>"
			act := i < len(actual_lines) ? actual_lines[i] : "<END OF TREE>"

			if exp != act {
				log.errorf("%-4d | %-50q | %-50q <-- MISMATCH!\n", i + 1, exp, act)
			} else {
				log.errorf("%-4d | %-50s | %-50s\n", i + 1, exp, act)
			}
		}
		log.errorf("========================================\n")
		testing.fail(t)

		dump_file, err := os.create("./tests/parser/dumped/ast_dump.txt")

		buffer_len := 1
		for line in actual_lines {
			buffer_len += len(line) + 1
		}
		buffer := make([]u8, buffer_len)
		index := 0
		for line in actual_lines {
			for char in line {
				buffer[index] = cast(u8)(char)
				index += 1
			}
			buffer[index] = '\n'
			index += 1
		}
		os.write(dump_file, buffer)
		os.close(dump_file)
		delete(buffer)
		log.errorf("\n\n\nDumped AST into ./tests/parser/dumped/ast_dump.text\n\n")
	}
}
