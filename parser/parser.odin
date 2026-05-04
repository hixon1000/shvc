package parser

import "ast"
import "stack"
import "tokens"

parse_expression :: proc(tokenizer: ^Tokenizer) -> ^ast.AST_Node {
	operator_stack := stack.make_stack(tokens.Token, context.temp_allocator)
	operand_stack := stack.make_stack(^ast.AST_Node, context.temp_allocator)

	for {
		// token := next_token(tokenizer, context.temp_allocator)

    #partial switch _ in token {
		case tokens.Semi_Colon, tokens.Close_Bracket, tokens.Open_Bracket:
			break
		}


	}
}
