package ast

import "../stock_types"
import "../tokens"


Type_Pair :: struct {
	name: string, // TODO: think of namespacing
	type: stock_types.Types,
}

Block :: struct {
	items: ^[dynamic]^AST_Node,
}

Program :: struct {
	statements: Block,
}

Call :: struct {
	target: ^AST_Node,
	args:   ^[dynamic]^AST_Node,
}

Var_Decl :: struct {
	name:      string,
	is_mut:    bool,
	type_info: stock_types.Types,
	init_expr: ^AST_Node,
}

Fn_Decl :: struct {
	name:     string,
	args:     ^[dynamic]Type_Pair,
	ret_type: stock_types.Types,
	body:     ^Block,
}

Struct_Decl :: struct {
	name:   string,
	fields: ^[dynamic]Type_Pair,
}

If_Stmt :: struct {
	condition: ^AST_Node,
	body:      ^AST_Node, // usually a block, may be a single statement for do
	else_stmt: ^AST_Node, // can be nil, another If_Stmt, or Block
}

Defer_Stmt :: struct {
	stmt: ^AST_Node,
}

For_Loop :: struct {
	// TODO: consider this
	init: ^AST_Node,
	cond: ^AST_Node,
	step: ^AST_Node,
	body: ^Block,
}

Identifier :: struct {
	name: string,
}

Literal :: struct {
	type:  stock_types.Types,
	value: string,
}

Binary_Op :: struct {
	left:  ^AST_Node,
	op:    tokens.Token,
	right: ^AST_Node,
}

Unary_Op :: struct {
	op:      tokens.Token,
	operand: ^AST_Node,
}

AST_Node :: union {
	Program,
	Block,
	Call,
	Var_Decl,
	Fn_Decl,
	Struct_Decl,
	If_Stmt,
	Defer_Stmt,
	For_Loop,
	Identifier,
	Literal,
	Binary_Op,
	Unary_Op,
}
