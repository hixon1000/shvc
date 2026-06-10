package ast

import "../stock_types"
import "../tokens"


Type_Pair :: struct {
	name:   string, // TODO: think of namespacing
	is_mut: bool,
	type:   stock_types.Types,
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

Var_Init_Kind :: enum {
	Zero, // val a: i32
	Expr, // val a: i32 = something
	Undef, // val a: i32 = ?
}

Var_Decl :: struct {
	name:      string,
	is_mut:    bool,
	type_info: stock_types.Types,
	init_expr: ^AST_Node,
	init_kind: Var_Init_Kind,
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

Trait_Decl :: struct {
	name:    string,
	methods: ^[dynamic]Fn_Decl,
}

If_Stmt :: struct {
	condition: ^AST_Node,
	body:      ^AST_Node, // usually a block, may be a single statement for do
	else_stmt: ^AST_Node, // can be nil, another If_Stmt, or Block
}

Array_Literal :: struct {
	items: ^[dynamic]^AST_Node,
}

Struct_Literal_Field :: struct {
	name:  string,
	value: ^AST_Node,
}

Struct_Literal :: struct {
	type:   ^AST_Node,
	fields: ^[dynamic]Struct_Literal_Field,
}

Index_Expr :: struct {
	target: ^AST_Node,
	index:  ^AST_Node,
}

Slice_Expr :: struct {
	target: ^AST_Node,

	// nil -> omitted
	// a[:]   => start=nil, end=nil
	// a[i:]  => start=i, end=nil
	// a[:j]  => start=nil, end=j
	// a[i:j] => start=i, end=j
	start:  ^AST_Node,
	end:    ^AST_Node,
}

Cast_Expr :: struct {
	expr:           ^AST_Node,
	target_type:    stock_types.Types,
	is_reinterpret: bool,
}

Defer_Stmt :: struct {
	stmt: ^AST_Node,
}

Return_Stmt :: struct {
	// may be nil
	expr: ^AST_Node,
}

Continue_Stmt :: struct {}
Break_Stmt :: struct {}

For_Kind :: enum {
	Infinite,
	Each,
	C_Style,
}

For_Stmt :: struct {
	kind:            For_Kind,

	// for { }
	body:            ^AST_Node,

	// for i in array { }
	// for i, index in array { }
	iter_value_name: Identifier,
	iter_index_name: Identifier, // empty if absent
	iter_expr:       ^AST_Node,

	// for init; condition; post { }
	init:            ^AST_Node,
	condition:       ^AST_Node,
	post:            ^AST_Node,
}

Identifier :: struct {
	name: string,
}

Int_Literal :: struct {
	value: i32,
}

Float_Literal :: struct {
	value: f32,
}

String_Literal :: struct {
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

Field_Access :: struct {
	target: ^AST_Node,
	field:  string,
}

Method_Call :: struct {
	target: ^AST_Node,
	method: string,
	args:   ^[dynamic]^AST_Node,
}

AST_Node :: union {
	Program,
	Block,
	Call,
	Var_Decl,
	Fn_Decl,
	Struct_Decl,
	Trait_Decl,
	If_Stmt,
	Array_Literal,
	Struct_Literal,
	Struct_Literal_Field,
	Index_Expr,
	Slice_Expr,
	Cast_Expr,
	Defer_Stmt,
	Return_Stmt,
	Continue_Stmt,
	Break_Stmt,
	For_Stmt,
	Identifier,
	Int_Literal,
	Float_Literal,
	String_Literal,
	Binary_Op,
	Unary_Op,
	Field_Access,
	Method_Call,
}
