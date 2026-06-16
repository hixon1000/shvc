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

import "base:runtime"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import "tokens"

Tokenizer :: struct {
	source:       [dynamic]rune, // somehow
	cursor:       int, // index of the cursor, each index is one rune
	peeked_token: tokens.Spanned_Token,
	has_peeked:   bool,
}

new_tokenizer :: proc(allocator: runtime.Allocator) -> ^Tokenizer { 	// i dont know the size of the source code ahead of time
	rune_array := make([dynamic]rune, allocator)
	return new_clone(Tokenizer{source = rune_array}, allocator)
}

// put new source code into the tokenizer
// it has to be rune either way
inject_src :: proc(tokenizer: ^Tokenizer, src: string) {
	for char in src {
		append(&tokenizer.source, char)
	}
}

// return rune at cursor
peek :: proc(tokenizer: ^Tokenizer) -> rune {
	if is_at_end(tokenizer) {
		panic("peek failed") // TODO: actual error handling
	}
	return tokenizer.source[tokenizer.cursor]
}

is_at_end :: proc(tokenizer: ^Tokenizer) -> bool {
	// i shouldnt worry about performance
	return len(tokenizer.source) <= tokenizer.cursor
}

// next rune
advance :: proc(tokenizer: ^Tokenizer, n := 1) {
	tokenizer.cursor += n
}

is_ident_char :: proc(r: rune) -> bool {
	return unicode.is_alpha(r) || unicode.is_digit(r) || r == '_'
}

unget_token :: proc(tokenizer: ^Tokenizer, token: tokens.Spanned_Token) {
	tokenizer.peeked_token = token
	tokenizer.has_peeked = true
}

peek_next :: proc(tokenizer: ^Tokenizer) -> (result: rune, ok: bool) #optional_ok {
	// sometimes throw and catch aint that bad honestly
	// just thinking about bobbing the error makes me nauseous

	// bad
	if len(tokenizer.source) <= tokenizer.cursor + 1 {
		return // ok is false by default
	}

	result = tokenizer.source[tokenizer.cursor + 1]
	ok = true
	return
}

spanned :: proc(tokenizer: ^Tokenizer, start: int, kind: tokens.Token) -> tokens.Spanned_Token {
	return tokens.Spanned_Token {
		kind = kind,
		span = tokens.Span{start = start, end = tokenizer.cursor},
	}
}

scan_token :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> tokens.Spanned_Token {
	if !skip_whitespace_and_comments(tokenizer) {
		panic("unterminated block comment")
	}

	start := tokenizer.cursor

	if is_at_end(tokenizer) {
		return spanned(tokenizer, start, tokens.Eof{})
	}

	char := peek(tokenizer)

	switch char {
	case ':':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Colon{})
	case '-':
		if n, ok := peek_next(tokenizer); ok && n == '>' {
			advance(tokenizer, 2)
			return spanned(tokenizer, start, tokens.Arrow{})
		}
		if n, ok := peek_next(tokenizer); ok && n == '=' {
			advance(tokenizer, 2)
			return spanned(tokenizer, start, tokens.Minus_Assign{}) // For i -= 1
		}
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Minus{})
	case '^':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Caret{})
	case '&':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Ampersand{})
	case '=':
		if n, ok := peek_next(tokenizer); ok && n == '=' { 	// ==
			advance(tokenizer, 2)
			return spanned(tokenizer, start, tokens.Equal{})
		}
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Assign{})
	case '!':
		if n, ok := peek_next(tokenizer); ok && n == '=' {
			advance(tokenizer, 2)
			return spanned(tokenizer, start, tokens.Not_Equal{})
		}
		panic("unexpected character: !")
	case ',':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Comma{})
	case '?':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Question{})
	case '.':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Dot{})
	case ';':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Semi_Colon{})
	case '+':
		if n, ok := peek_next(tokenizer); ok && n == '=' {
			advance(tokenizer, 2)
			return spanned(tokenizer, start, tokens.Plus_Assign{})
		}
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Plus{})
	case '*':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Star{})
	case '/':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Slash{})
	case '<':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Less{})
	case '>':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Greater{})

	case '(':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Open_Paren{})
	case ')':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Close_Paren{})
	case '{':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Open_Bracket{})
	case '}':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Close_Bracket{})
	case '[':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Open_SB{})
	case ']':
		advance(tokenizer)
		return spanned(tokenizer, start, tokens.Close_SB{})

	// normal string literal
	case '"':
		advance(tokenizer) // consume the opening quote
		b := strings.builder_make(context.temp_allocator)

		for !is_at_end(tokenizer) && peek(tokenizer) != '"' {
			c := peek(tokenizer)
			if c == '\\' {
				advance(tokenizer) // consume \
				if is_at_end(tokenizer) {
					panic("unterminated escape sequence") // TODO: proper error handling
				}

				escaped_char := peek(tokenizer)
				switch escaped_char {
				case 'n':
					strings.write_rune(&b, '\n')
				case 't':
					strings.write_rune(&b, '\t')
				case 'r':
					strings.write_rune(&b, '\r')
				case '\\':
					strings.write_rune(&b, '\\')
				case '"':
					strings.write_rune(&b, '"')
				case:
					// dunno what escape sequence this is, treat as literal
					strings.write_rune(&b, escaped_char)
				}
				advance(tokenizer)
				continue
			} else {
				strings.write_rune(&b, c)
				advance(tokenizer)
			}
		}

		if is_at_end(tokenizer) {
			panic("unclosed string literal") // TODO: proper error handling
		}
		advance(tokenizer)

		return spanned(
			tokenizer,
			start,
			tokens.String_Literal{strings.clone(strings.to_string(b), allocator)},
		)

	case '`':
		advance(tokenizer) // consume opening backtick
		raw_start := tokenizer.cursor

		for !is_at_end(tokenizer) && peek(tokenizer) != '`' {
			advance(tokenizer)
		}

		if is_at_end(tokenizer) do panic("unterminated raw string literal")

		raw_slice := tokenizer.source[raw_start:tokenizer.cursor]
		advance(tokenizer) // consume closing backtick

		temp_str := utf8.runes_to_string(raw_slice, context.temp_allocator)
		return spanned(tokenizer, start, tokens.String_Literal{strings.clone(temp_str, allocator)})
	}

	if unicode.is_alpha(char) || char == '_' {
		ident_start := tokenizer.cursor
		for !is_at_end(tokenizer) && is_ident_char(peek(tokenizer)) {
			advance(tokenizer)
		}

		text_slice := tokenizer.source[ident_start:tokenizer.cursor]

		text := utf8.runes_to_string(text_slice, context.temp_allocator)

		switch text {
		case "val":
			return spanned(tokenizer, ident_start, tokens.Val{})
		case "mut":
			return spanned(tokenizer, ident_start, tokens.Mut{})
		case "fn":
			return spanned(tokenizer, ident_start, tokens.Fn{})
		case "trait":
			return spanned(tokenizer, ident_start, tokens.Trait{})
		case "return":
			return spanned(tokenizer, ident_start, tokens.Return{})
		case "if":
			return spanned(tokenizer, ident_start, tokens.If{})
		case "else":
			return spanned(tokenizer, ident_start, tokens.Else{})
		case "do":
			return spanned(tokenizer, ident_start, tokens.Do{})
		case "struct":
			return spanned(tokenizer, ident_start, tokens.Struct{})
		case "for":
			return spanned(tokenizer, ident_start, tokens.For{})
		case "defer":
			return spanned(tokenizer, ident_start, tokens.Defer{})
		case "in":
			return spanned(tokenizer, ident_start, tokens.In{})
		case "break":
			return spanned(tokenizer, ident_start, tokens.Break{})
		case "continue":
			return spanned(tokenizer, ident_start, tokens.Continue{})

		case "as":
			// if next is !
			if !is_at_end(tokenizer) && peek(tokenizer) == '!' {
				advance(tokenizer)
				return spanned(tokenizer, ident_start, tokens.As_Bang{})
			}
			return spanned(tokenizer, ident_start, tokens.As{})

		case:
			return spanned(
				tokenizer,
				ident_start,
				tokens.Identifier{strings.clone(text, allocator)},
			)
		}
	}

	if unicode.is_digit(char) {
		num_start := tokenizer.cursor
		is_float := false

		// eat init digits
		for !is_at_end(tokenizer) && unicode.is_digit(peek(tokenizer)) {
			advance(tokenizer)
		}

		// check for fractional part
		if !is_at_end(tokenizer) && peek(tokenizer) == '.' {
			// ensure next char is a digit
			// in case we want a range op (we probably wont have it)
			if nxt, ok := peek_next(tokenizer); ok && unicode.is_digit(nxt) {
				is_float = true
				advance(tokenizer) // eat period .
				for !is_at_end(tokenizer) && unicode.is_digit(peek(tokenizer)) {
					advance(tokenizer)
				}
			}
		}

		// scientific stuff
		if !is_at_end(tokenizer) && (peek(tokenizer) == 'e' || peek(tokenizer) == 'E') {
			saved_cursor := tokenizer.cursor
			advance(tokenizer) // consume e or E

			// optional sign
			if !is_at_end(tokenizer) && (peek(tokenizer) == '+' || peek(tokenizer) == '-') {
				advance(tokenizer)
			}

			// should be followed by at least one digit to be a valid exponent
			if !is_at_end(tokenizer) && unicode.is_digit(peek(tokenizer)) {
				is_float = true
				for !is_at_end(tokenizer) && unicode.is_digit(peek(tokenizer)) {
					advance(tokenizer)
				}
			} else {
				// not a valid exponent suffix
				// roll back the cursor so the e can be parsed normally later
				tokenizer.cursor = saved_cursor
			}
		}

		// extract, parse, profit
		num_slice := tokenizer.source[num_start:tokenizer.cursor]
		num_str := utf8.runes_to_string(num_slice, context.temp_allocator)

		if is_float {
			val, ok := strconv.parse_f32(num_str)
			if !ok {
				panic("fail to parse float") // TODO: proper error handling
			}
			return spanned(tokenizer, num_start, tokens.Float_Literal{val})
		} else {
			val, ok := strconv.parse_int(num_str)
			if !ok {
				panic("fail to parse int") // TODO: proper error handling
			}
			return spanned(tokenizer, num_start, tokens.Int_Literal{cast(i32)val})
		}
	}

	fmt.println("unexpected character:", char)
	panic("unexpected character")
}

next_token :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> tokens.Spanned_Token {
	if tokenizer.has_peeked {
		tokenizer.has_peeked = false
		return tokenizer.peeked_token
	}

	return scan_token(tokenizer, allocator)
}

peek_token :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> tokens.Spanned_Token {
	if !tokenizer.has_peeked {
		tokenizer.peeked_token = scan_token(tokenizer, allocator)
		tokenizer.has_peeked = true
	}

	return tokenizer.peeked_token
}

// if true means success
// if false it means the user forgot to close their comments (probably)
skip_whitespace_and_comments :: proc(tokenizer: ^Tokenizer) -> bool {
	for !is_at_end(tokenizer) {
		c := peek(tokenizer)

		if unicode.is_white_space(c) {
			advance(tokenizer)
			continue
		}

		if c == '/' {
			next, ok := peek_next(tokenizer)
			if !ok do break

			if next == '/' {
				for !is_at_end(tokenizer) && peek(tokenizer) != '\n' {
					advance(tokenizer)
				}
				continue
			}

			if next == '*' {
				advance(tokenizer, 2)

				closed := false
				for !is_at_end(tokenizer) {
					curr := peek(tokenizer)
					nxt, nxt_ok := peek_next(tokenizer)

					if curr == '*' && nxt_ok && nxt == '/' {
						advance(tokenizer, 2)
						closed = true
						break
					}

					advance(tokenizer)
				}

				if !closed {
					return false
				}

				continue
			}
		}

		break
	}

	return true
}
