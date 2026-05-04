package ast

import "../tokens"

Type :: union {}

Type_Pair :: struct {
	name: string, // TODO: think of namespacing
	type: Type,
}

Program :: struct {
	statements: [dynamic]^AST_Node,
}

Block :: struct {
	statements: [dynamic]^AST_Node,
}

Var_Decl :: struct {
	name:      string,
	is_mut:    bool,
	type_info: Type,
	init_expr: ^AST_Node,
}

Fn_Decl :: struct {
	name:     string,
	args:     [dynamic]Type_Pair,
	ret_type: Type,
	body:     ^AST_Node,
}

Struct_Decl :: struct {
	name:   string,
	fields: [dynamic]Type_Pair,
}

If_Stmt :: struct {
	// TODO: think of many branches
	condition: ^AST_Node,
	body:      ^AST_Node,
}

For_Loop :: struct {
	// TODO: consider this
	init: ^AST_Node,
	cond: ^AST_Node,
	step: ^AST_Node,
	body: ^AST_Node,
}

Identifier :: struct {
	name: string,
}

Literal :: struct {
	type:  Type,
	value: string,
}

Binary_Op :: struct {
	left:  ^AST_Node,
	op:    tokens.Token, // this might cause cyclic deps issue
	right: ^AST_Node,
}

Unary_Op :: struct {
	op:      tokens.Token,
	operand: ^AST_Node,
}

AST_Node :: union {
	Program,
	Block,
	Var_Decl,
	Fn_Decl,
	Struct_Decl,
	If_Stmt,
	For_Loop,
	Identifier,
	Literal,
	Binary_Op,
	Unary_Op,
}
