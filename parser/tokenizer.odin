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
	peeked_token: tokens.Token,
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

unget_token :: proc(tokenizer: ^Tokenizer, token: tokens.Token) {
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


scan_token :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> tokens.Token {
	if !skip_whitespace_and_comments(tokenizer) {
		panic("unterminated block comment")
	}

	if is_at_end(tokenizer) {
		return tokens.Eof{}
	}

	char := peek(tokenizer)

	switch char {
	case ':':
		advance(tokenizer)
		return tokens.Colon{}
	case '-':
		if n, ok := peek_next(tokenizer); ok && n == '>' {
			advance(tokenizer, 2)
			return tokens.Arrow{}
		}
		advance(tokenizer)
		return tokens.Minus{}
	case '^':
		advance(tokenizer)
		return tokens.Caret{}
	case '&':
		advance(tokenizer)
		return tokens.Ampersand{}
	case '=':
		if n, ok := peek_next(tokenizer); ok && n == '=' { 	// ==
			advance(tokenizer, 2)
			return tokens.Equal{}
		}
		advance(tokenizer)
		return tokens.Assign{}
	case '!':
		if n, ok := peek_next(tokenizer); ok && n == '=' {
			advance(tokenizer, 2)
			return tokens.Not_Equal{}
		}
		panic("unexpected character: !")
	case ',':
		advance(tokenizer)
		return tokens.Comma{}
  case '?':
    advance(tokenizer)
    return tokens.Question{}
	case ';':
		advance(tokenizer)
		return tokens.Semi_Colon{}
	case '+':
		advance(tokenizer)
		return tokens.Plus{}
	case '*':
		advance(tokenizer)
		return tokens.Star{}
	case '/':
		advance(tokenizer)
		return tokens.Slash{}
	case '<':
		advance(tokenizer)
		return tokens.Less{}
	case '>':
		advance(tokenizer)
		return tokens.Greater{}

	case '(':
		advance(tokenizer)
		return tokens.Open_Paren{}
	case ')':
		advance(tokenizer)
		return tokens.Close_Paren{}
	case '{':
		advance(tokenizer)
		return tokens.Open_Bracket{}
	case '}':
		advance(tokenizer)
		return tokens.Close_Bracket{}
	case '[':
		advance(tokenizer)
		return tokens.Open_SB{}
	case ']':
		advance(tokenizer)
		return tokens.Close_SB{}

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

		return tokens.String_Literal{strings.clone(strings.to_string(b), allocator)}

	case '`':
		advance(tokenizer) // consume opening backtick
		start := tokenizer.cursor

		for !is_at_end(tokenizer) && peek(tokenizer) != '`' {
			advance(tokenizer)
		}

		if is_at_end(tokenizer) do panic("unterminated raw string literal")

		raw_slice := tokenizer.source[start:tokenizer.cursor]
		advance(tokenizer) // consume closing backtick

		temp_str := utf8.runes_to_string(raw_slice, context.temp_allocator)
		return tokens.String_Literal{strings.clone(temp_str, allocator)}
	}

	if unicode.is_alpha(char) || char == '_' {
		start := tokenizer.cursor
		for !is_at_end(tokenizer) && is_ident_char(peek(tokenizer)) {
			advance(tokenizer)
		}

		text_slice := tokenizer.source[start:tokenizer.cursor]

		text := utf8.runes_to_string(text_slice, context.temp_allocator)

		switch text {
		case "val":
			return tokens.Val{}
		case "mut":
			return tokens.Mut{}
		case "fn":
			return tokens.Fn{}
		case "return":
			return tokens.Return{}
		case "if":
			return tokens.If{}
		case "else":
			return tokens.Else{}
		case "do":
			return tokens.Do{}
		case "struct":
			return tokens.Struct{}
		case "for":
			return tokens.For{}
		case "defer":
			return tokens.Defer{}
		case "in":
			return tokens.In{}
		case "break":
			return tokens.Break{}
		case "continue":
			return tokens.Continue{}

		case:
			return tokens.Identifier{strings.clone(text, allocator)}
		}
	}

	// TODO: float

	if unicode.is_digit(char) {
		start := tokenizer.cursor
		for !is_at_end(tokenizer) && unicode.is_digit(peek(tokenizer)) {
			advance(tokenizer)
		}
		int_slice := tokenizer.source[start:tokenizer.cursor]

		integer_str := utf8.runes_to_string(int_slice, context.temp_allocator)
		val, ok := strconv.parse_int(integer_str)
		if !ok {
			panic("fail to parse int") // TODO: proper error handling
		}
		return tokens.Int_Literal{cast(i32)val} // TODO: think about this
	}

	fmt.println("unexpected character:", char)
	panic("unexpected character")
}

next_token :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> tokens.Token {
	if tokenizer.has_peeked {
		tokenizer.has_peeked = false
		return tokenizer.peeked_token
	}

	return scan_token(tokenizer, allocator)
}

peek_token :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> tokens.Token {
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
