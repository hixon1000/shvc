package parser

import "ast"
import "base:runtime"
import "stack"
import "tokens"

precedence :: proc(token: tokens.Token) -> u8 {
	#partial switch _ in token {
	case tokens.Assign, tokens.Plus_Assign, tokens.Minus_Assign:
		return 1
	case tokens.Equal, tokens.Not_Equal:
		return 2
	case tokens.Less, tokens.Greater:
		return 3
	case tokens.Plus, tokens.Minus:
		return 4
	case tokens.Star, tokens.Slash:
		return 5
	case tokens.Ampersand, tokens.Caret:
		return 6
	}
	panic("precedence input token not an operator") // TODO: proper error handling
}

create_leaf_node :: proc(token: tokens.Token, alloc: runtime.Allocator) -> ^ast.AST_Node { 	// alloc should be in the arena
	node := new(ast.AST_Node, alloc)

	#partial switch t in token {
	case tokens.Identifier:
		node^ = ast.Identifier {
			name = t.content,
		}
		return node

	case tokens.Int_Literal:
		node^ = ast.Int_Literal {
			value = t.content,
		}
		return node

	case tokens.Float_Literal:
		node^ = ast.Float_Literal {
			value = t.content,
		}
		return node

	case tokens.String_Literal:
		node^ = ast.String_Literal {
			value = t.content,
		}
		return node

	case:
		panic("expected an identifier or literal")
	}
}

create_binary_node :: proc(
	left: ^ast.AST_Node,
	op: tokens.Token,
	right: ^ast.AST_Node,
	arena: runtime.Allocator,
) -> ^ast.AST_Node { 	// do this even need allocation
	node: ast.AST_Node = ast.Binary_Op {
		left  = left,
		op    = op,
		right = right,
	}
	return new_clone(node, arena)
}

create_unary_node :: proc(
	op: tokens.Token,
	operand: ^ast.AST_Node,
	arena: runtime.Allocator,
) -> ^ast.AST_Node {
	node := new(ast.AST_Node, arena)
	node^ = ast.Unary_Op {
		op      = op,
		operand = operand,
	}
	return node
}

apply_operator :: proc(
	operator_stack: ^stack.Stack(tokens.Token),
	operand_stack: ^stack.Stack(^ast.AST_Node),
	arena: runtime.Allocator,
) {
	op, ostack_ok := stack.pop(operator_stack)
	if !ostack_ok do panic("missing operator")

	if is_unary(op) {
		operand, ostack_u_ok := stack.pop(operand_stack)
		if !ostack_u_ok do panic("missing unary operand")

		stack.push(operand_stack, create_unary_node(op, operand, arena))
		return
	}

	#partial switch _ in op {
	case tokens.Assign,
	     tokens.Plus_Assign,
	     tokens.Minus_Assign,
	     tokens.Plus,
	     tokens.Minus,
	     tokens.Star,
	     tokens.Slash,
	     tokens.Equal,
	     tokens.Not_Equal,
	     tokens.Less,
	     tokens.Greater:
		right, rok := stack.pop(operand_stack)
		left, lok := stack.pop(operand_stack)

		if !rok || !lok do panic("missing binary operand")

		stack.push(operand_stack, create_binary_node(left, op, right, arena))
	case:
		panic("compiler error: unknown operator on stack")
	}
}

is_right_assoc :: proc(token: tokens.Token) -> bool {
	#partial switch _ in token {
	case tokens.Assign, tokens.Plus_Assign, tokens.Minus_Assign:
		return true
	}
	return false
}

is_unary :: proc(token: tokens.Token) -> bool {
	#partial switch _ in token {
	case tokens.Ampersand, tokens.Caret:
		return true
	}
	return false
}
