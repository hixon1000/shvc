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
import "../../parser/tokens"
import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:strings"
import "core:testing"

LARGE_SRC :: #load("fixtures/main.shv", string)
EXPECTED_TOK :: #load("fixtures/main.shv.tokens", string)

@(test)
test_entire_token_chain :: proc(t: ^testing.T) {
	arena: virtual.Arena
	_ = virtual.arena_init_growing(&arena)
	alloc := virtual.arena_allocator(&arena)
	defer virtual.arena_destroy(&arena)

	tokenizer := parser.new_tokenizer(alloc)
	parser.inject_src(tokenizer, LARGE_SRC)

	expected_clean, _ := strings.replace_all(EXPECTED_TOK, "\r\n", "\n", alloc)
	expected_lines := strings.split_lines(strings.trim_space(expected_clean), alloc)

	actual_lines := make([dynamic]string, alloc)

	for {
		spanned := parser.next_token(tokenizer, alloc)
		token_str := fmt.tprintf("%v", spanned.kind)
		append(&actual_lines, strings.trim_space(token_str))

		if _, is_eof := spanned.kind.(tokens.Eof); is_eof {
			break
		}
	}

	max_lines := max(len(expected_lines), len(actual_lines))

	had_err := false
	for i := 0; i < max_lines; i += 1 {
		exp := i < len(expected_lines) ? expected_lines[i] : "<END OF STREAM>"
		act := i < len(actual_lines) ? actual_lines[i] : "<END OF STREAM>"
		if exp != act {
			log.errorf("on line: %i - Expected: %s - Actual: %s\n", i + 1, exp, act)
			testing.fail(t)
			had_err = true
		}
	}

	if had_err {
		dump_file, err := os.create("./tests/parser/dumped/tokens_dump.txt")

		if err == nil {
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
			log.errorf("\n\n\nDumped Tokens into ./tests/parser/dumped/tokens_dump.text\n\n")
		}
	}
}
