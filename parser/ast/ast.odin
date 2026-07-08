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

package ast

import "../stock_types"
import "../tokens"


Type_Pair :: struct {
	name:   string, // TODO: think of namespacing
	is_mut: bool,
	type:   stock_types.Types,
}

Block :: struct {
	items: ^[dynamic]^Spanned_AST,
}

Program :: struct {
	statements: Block,
}

Call :: struct {
	target: ^Spanned_AST,
	args:   ^[dynamic]^Spanned_AST,
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
	init_expr: ^Spanned_AST,
	init_kind: Var_Init_Kind,
}

Fn_Decl :: struct {
	name:     string,
	args:     ^[dynamic]Type_Pair,
	ret_type: stock_types.Types,
	body:     ^Spanned_AST, // kind must be Block
}

Struct_Decl :: struct {
	name:   string,
	fields: ^[dynamic]Type_Pair,
}

Trait_Decl :: struct {
	name:    string,
	methods: ^[dynamic]Spanned_AST, // kind must be Fn_Decl
}

If_Stmt :: struct {
	condition: ^Spanned_AST,
	body:      ^Spanned_AST, // usually a block, may be a single statement for do
	else_stmt: ^Spanned_AST, // can be nil, another If_Stmt, or Block
}

Array_Literal :: struct {
	items: ^[dynamic]^Spanned_AST,
}

Struct_Literal_Field :: struct {
	name:  string,
	value: ^Spanned_AST,
}

Struct_Literal :: struct {
	type:   ^Spanned_AST,
	fields: ^[dynamic]Spanned_AST, // kind must be Struct_Literal_Field
}

Index_Expr :: struct {
	target: ^Spanned_AST,
	index:  ^Spanned_AST,
}

Slice_Expr :: struct {
	target: ^Spanned_AST,

	// nil -> omitted
	// a[:]   => start=nil, end=nil
	// a[i:]  => start=i, end=nil
	// a[:j]  => start=nil, end=j
	// a[i:j] => start=i, end=j
	start:  ^Spanned_AST,
	end:    ^Spanned_AST,
}

Cast_Expr :: struct {
	expr:           ^Spanned_AST,
	target_type:    stock_types.Types,
	is_reinterpret: bool,
}

Defer_Stmt :: struct {
	stmt: ^Spanned_AST,
}

Return_Stmt :: struct {
	// may be nil
	expr: ^Spanned_AST,
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
	body:            ^Spanned_AST,

	// for i in array { }
	// for i, index in array { }
	iter_value_name: Identifier,
	iter_index_name: Identifier, // empty if absent
	iter_expr:       ^Spanned_AST,

	// for init; condition; post { }
	init:            ^Spanned_AST,
	condition:       ^Spanned_AST,
	post:            ^Spanned_AST,
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
	left:  ^Spanned_AST,
	op:    tokens.Token,
	right: ^Spanned_AST,
}

Unary_Op :: struct {
	op:      tokens.Token,
	operand: ^Spanned_AST,
}

Field_Access :: struct {
	target: ^Spanned_AST,
	field:  string,
}

Method_Call :: struct {
	target: ^Spanned_AST,
	method: string,
	args:   ^[dynamic]^Spanned_AST,
}

Spanned_AST :: struct {
	kind: AST_Node,
	span: tokens.Span,
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
