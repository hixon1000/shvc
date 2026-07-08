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

import "ast"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

debug_ast_print :: proc(result: Parse_Result) {
	arena: virtual.Arena
	_ = virtual.arena_init_growing(&arena)
	alloc := virtual.arena_allocator(&arena)

	fmt.print(debug_ast_dump(result, alloc))

	virtual.arena_destroy(&arena)
}

debug_ast_dump :: proc(result: Parse_Result, alloc: mem.Allocator) -> string {
	b := strings.builder_make(alloc)
	strings.write_string(&b, "=== AST DUMP ===\n")
	write_node(&b, result.root, 0)
	strings.write_string(&b, "================\n")
	return strings.to_string(b)
}

write_indent :: proc(b: ^strings.Builder, indent: int) {
	for _ in 0 ..< indent {
		strings.write_string(b, "  ")
	}
}

write_node :: proc(b: ^strings.Builder, node: ^ast.Spanned_AST, indent: int) {
	if node == nil {
		write_indent(b, indent)
		strings.write_string(b, "<nil>\n")
		return
	}

	write_indent(b, indent)

	switch v in node.kind {
	case ast.Program:
		fmt.sbprintf(b, "Program: Span: %d..%d\n", node.span.start, node.span.end)
		if v.statements.items != nil {
			for stmt in v.statements.items^ {
				write_node(b, stmt, indent + 1)
			}
		}

	case ast.Block:
		fmt.sbprintf(b, "Block: Span: %d..%d\n", node.span.start, node.span.end)
		if v.items != nil {
			for stmt in v.items^ {
				write_node(b, stmt, indent + 1)
			}
		}

	case ast.Fn_Decl:
		fmt.sbprintf(b, "Fn_Decl: %s Span: %d..%d\n", v.name, node.span.start, node.span.end)

		write_indent(b, indent + 1)
		strings.write_string(b, "Args: [")
		if v.args != nil {
			for arg, i in v.args^ {
				if i > 0 {
					strings.write_string(b, ", ")
				}
				if arg.is_mut {
					strings.write_string(b, "mut ")
				}
				fmt.sbprintf(b, "%s: %v", arg.name, arg.type)
			}
		}
		strings.write_string(b, "]\n")

		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Returns: %v\n", v.ret_type)

		if v.body != nil {
			write_indent(b, indent + 1)
			fmt.sbprintf(b, "Body: Span: %d..%d\n", v.body.span.start, v.body.span.end)
			if v.body.kind.(ast.Block).items != nil {
				for stmt in v.body.kind.(ast.Block).items^ {
					write_node(b, stmt, indent + 2)
				}
			}
		}

	case ast.Struct_Decl:
		fmt.sbprintf(b, "Struct_Decl: %s Span: %d..%d\n", v.name, node.span.start, node.span.end)

		write_indent(b, indent + 1)
		strings.write_string(b, "Fields: [")
		if v.fields != nil {
			for field, i in v.fields^ {
				if i > 0 {
					strings.write_string(b, ", ")
				}
				fmt.sbprintf(b, "%s: %v", field.name, field.type)
			}
		}
		strings.write_string(b, "]\n")

	case ast.Trait_Decl:
		fmt.sbprintf(b, "Trait_Decl: %s Span: %d..%d\n", v.name, node.span.start, node.span.end)

		if v.methods != nil {
			write_indent(b, indent + 1)
			strings.write_string(b, "Methods:\n")

			for method in v.methods^ {
				method_node: ast.Spanned_AST = method
				write_node(b, &method_node, indent + 2)
			}
		}

	case ast.Binary_Op:
		fmt.sbprintf(b, "Binary_Op: %v Span: %d..%d\n", v.op, node.span.start, node.span.end)
		write_node(b, v.left, indent + 1)
		write_node(b, v.right, indent + 1)

	case ast.Unary_Op:
		fmt.sbprintf(b, "Unary_Op: %v Span: %d..%d\n", v.op, node.span.start, node.span.end)
		write_node(b, v.operand, indent + 1)

	case ast.Identifier:
		fmt.sbprintf(b, "Identifier: %s Span: %d..%d\n", v.name, node.span.start, node.span.end)

	case ast.Int_Literal:
		fmt.sbprintf(b, "Int_Literal: %d Span: %d..%d\n", v.value, node.span.start, node.span.end)

	case ast.Float_Literal:
		fmt.sbprintf(b, "Float_Literal: %f Span: %d..%d\n", v.value, node.span.start, node.span.end)

	case ast.String_Literal:
		fmt.sbprintf(b, "String_Literal: %q Span: %d..%d\n", v.value, node.span.start, node.span.end)

	case ast.Var_Decl:
		fmt.sbprintf(b, "Var_Decl: %s Span: %d..%d\n", v.name, node.span.start, node.span.end)

		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Mut: %t\n", v.is_mut)

		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Kind: %s\n", v.init_kind)

		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Type: %v\n", v.type_info)

		if v.init_expr != nil {
			write_indent(b, indent + 1)
			strings.write_string(b, "Init:\n")
			write_node(b, v.init_expr, indent + 2)
		}

	case ast.If_Stmt:
		fmt.sbprintf(b, "If_Stmt: Span: %d..%d\n", node.span.start, node.span.end)

		write_indent(b, indent + 1)
		strings.write_string(b, "Condition:\n")
		write_node(b, v.condition, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Body:\n")
		write_node(b, v.body, indent + 2)

		if v.else_stmt != nil {
			write_indent(b, indent + 1)
			strings.write_string(b, "Else:\n")
			write_node(b, v.else_stmt, indent + 2)
		}

	case ast.Break_Stmt:
		fmt.sbprintf(b, "Break_Stmt Span: %d..%d\n", node.span.start, node.span.end)

	case ast.Continue_Stmt:
		fmt.sbprintf(b, "Continue_Stmt Span: %d..%d\n", node.span.start, node.span.end)

	case ast.For_Stmt:
		switch v.kind {
		case .Infinite:
			fmt.sbprintf(b, "For_Stmt (Infinite): Span: %d..%d\n", node.span.start, node.span.end)
			write_node(b, v.body, indent + 1)

		case .Each:
			fmt.sbprintf(b, "For_Stmt (Each): Span: %d..%d\n", node.span.start, node.span.end)

			write_indent(b, indent + 1)
			fmt.sbprintf(b, "value: %s\n", v.iter_value_name.name)

			if v.iter_index_name.name != "" {
				write_indent(b, indent + 1)
				fmt.sbprintf(b, "index: %s\n", v.iter_index_name.name)
			}

			write_indent(b, indent + 1)
			strings.write_string(b, "iterable:\n")
			write_node(b, v.iter_expr, indent + 2)

			write_indent(b, indent + 1)
			strings.write_string(b, "body:\n")
			write_node(b, v.body, indent + 2)

		case .C_Style:
			fmt.sbprintf(b, "For_Stmt (C-Style): Span: %d..%d\n", node.span.start, node.span.end)

			write_indent(b, indent + 1)
			strings.write_string(b, "init:\n")
			write_node(b, v.init, indent + 2)

			write_indent(b, indent + 1)
			strings.write_string(b, "condition:\n")
			write_node(b, v.condition, indent + 2)

			write_indent(b, indent + 1)
			strings.write_string(b, "post:\n")
			write_node(b, v.post, indent + 2)

			write_indent(b, indent + 1)
			strings.write_string(b, "body:\n")
			write_node(b, v.body, indent + 2)
		}

	case ast.Call:
		fmt.sbprintf(b, "Call: Span: %d..%d\n", node.span.start, node.span.end)

		write_indent(b, indent + 1)
		strings.write_string(b, "Target:\n")
		write_node(b, v.target, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Arguments:\n")
		if v.args != nil {
			for arg in v.args^ {
				write_node(b, arg, indent + 2)
			}
		}

	case ast.Defer_Stmt:
		fmt.sbprintf(b, "Defer_Stmt: Span: %d..%d\n", node.span.start, node.span.end)
		write_node(b, v.stmt, indent + 1)

	case ast.Return_Stmt:
		fmt.sbprintf(b, "Return_Stmt: Span: %d..%d\n", node.span.start, node.span.end)
		if v.expr != nil {
			write_node(b, v.expr, indent + 1)
		}

	case ast.Array_Literal:
		fmt.sbprintf(b, "Array_Literal: Span: %d..%d\n", node.span.start, node.span.end)
		if v.items != nil {
			for item in v.items^ {
				write_node(b, item, indent + 1)
			}
		}

	case ast.Struct_Literal:
		fmt.sbprintf(b, "Struct_Literal: Span: %d..%d\n", node.span.start, node.span.end)

		write_indent(b, indent + 1)
		strings.write_string(b, "Type:\n")
		write_node(b, v.type, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Fields:\n")
		if v.fields != nil {
			for field in v.fields^ {
				node: ast.Spanned_AST = field
				write_node(b, &node, indent + 2)
			}
		} else {
			write_indent(b, indent + 2)
			strings.write_string(b, "<nil>\n")
		}

	case ast.Struct_Literal_Field:
		fmt.sbprintf(b, "Struct_Literal_Field: %s = ", v.name)
		if v.value != nil {
			strings.write_string(b, "")
			fmt.sbprintf(b, "Span: %d..%d\n", node.span.start, node.span.end)
			write_node(b, v.value, indent + 1)
		} else {
			strings.write_string(b, "<nil>")
			fmt.sbprintf(b, "Span: %d..%d\n", node.span.start, node.span.end)
		}

	case ast.Index_Expr:
		fmt.sbprintf(b, "Index_Expr: Span: %d..%d\n", node.span.start, node.span.end)

		write_indent(b, indent + 1)
		strings.write_string(b, "Target:\n")
		write_node(b, v.target, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Index:\n")
		write_node(b, v.index, indent + 2)

	case ast.Slice_Expr:
		fmt.sbprintf(b, "Slice_Expr: Span: %d..%d\n", node.span.start, node.span.end)

		write_indent(b, indent + 1)
		strings.write_string(b, "Target:\n")
		write_node(b, v.target, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Start:\n")
		write_node(b, v.start, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "End:\n")
		write_node(b, v.end, indent + 2)

	case ast.Cast_Expr:
		fmt.sbprintf(b, "Cast_Expr: Span: %d..%d\n", node.span.start, node.span.end)
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Target_Type: %v\n", v.target_type)
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Is_Reinterpret: %t\n", v.is_reinterpret)
		write_indent(b, indent + 1)
		strings.write_string(b, "Expr:\n")
		write_node(b, v.expr, indent + 2)

	case ast.Field_Access:
		fmt.sbprintf(b, "Field_Access: Span: %d..%d\n", node.span.start, node.span.end)
		write_node(b, v.target, indent + 1)
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Field: %s\n", v.field)

	case ast.Method_Call:
		fmt.sbprintf(b, "Method_Call: Span: %d..%d\n", node.span.start, node.span.end)
		write_node(b, v.target, indent + 1)
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Method: %s\n", v.method)
		write_indent(b, indent + 1)
		strings.write_string(b, "Arguments:\n")
		if v.args != nil {
			for arg in v.args^ {
				write_node(b, arg, indent + 2)
			}
		}
	}
}

/*
Function kept for later refrence and when needed 
write_node_raw :: proc(b: ^strings.Builder, node: ^ast.AST_Node, indent: int) {
	if node == nil {
		write_indent(b, indent)
		strings.write_string(b, "<nil>\n")
		return
	}

	write_indent(b, indent)

	switch v in node^ {
	case ast.Program:
		strings.write_string(b, "Program:\n")
		if v.statements.items != nil {
			for stmt in v.statements.items^ {
				write_node(b, stmt, indent + 1)
			}
		}

	case ast.Block:
		strings.write_string(b, "Block:\n")
		if v.items != nil {
			for stmt in v.items^ {
				write_node(b, stmt, indent + 1)
			}
		}

	case ast.Fn_Decl:
		fmt.sbprintf(b, "Fn_Decl: %s\n", v.name)

		write_indent(b, indent + 1)
		strings.write_string(b, "Args: [")
		if v.args != nil {
			for arg, i in v.args^ {
				if i > 0 {
					strings.write_string(b, ", ")
				}
				if arg.is_mut {
					strings.write_string(b, "mut ")
				}
				fmt.sbprintf(b, "%s: %v", arg.name, arg.type)
			}
		}
		strings.write_string(b, "]\n")

		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Returns: %v\n", v.ret_type)

		if v.body != nil {
			write_indent(b, indent + 1)
			strings.write_string(b, "Body: ")
			fmt.sbprintf(b, "Span: %d..%d\n", v.body.span.start, v.body.span.end)
			if v.body.kind.(ast.Block).items != nil {
				for stmt in v.body.kind.(ast.Block).items^ {
					write_node(b, stmt, indent + 2)
				}
			}
		}

	case ast.Struct_Decl:
		fmt.sbprintf(b, "Struct_Decl: %s\n", v.name)

		write_indent(b, indent + 1)
		strings.write_string(b, "Fields: [")
		if v.fields != nil {
			for field, i in v.fields^ {
				if i > 0 {
					strings.write_string(b, ", ")
				}
				fmt.sbprintf(b, "%s: %v", field.name, field.type)
			}
		}
		strings.write_string(b, "]\n")

	case ast.Trait_Decl:
		fmt.sbprintf(b, "Trait_Decl: %s\n", v.name)

		if v.methods != nil {
			write_indent(b, indent + 1)
			strings.write_string(b, "Methods:\n")

			for method in v.methods^ {
				method_node: ast.Spanned_AST = method
				write_node(b, &method_node, indent + 2)
			}
		}

	case ast.Binary_Op:
		fmt.sbprintf(b, "Binary_Op: %v\n", v.op)
		write_node(b, v.left, indent + 1)
		write_node(b, v.right, indent + 1)

	case ast.Unary_Op:
		fmt.sbprintf(b, "Unary_Op: %v\n", v.op)
		write_node(b, v.operand, indent + 1)

	case ast.Identifier:
		fmt.sbprintf(b, "Identifier: %s\n", v.name)

	case ast.Int_Literal:
		fmt.sbprintf(b, "Int_Literal: %d\n", v.value)

	case ast.Float_Literal:
		fmt.sbprintf(b, "Float_Literal: %f\n", v.value)

	case ast.String_Literal:
		fmt.sbprintf(b, "String_Literal: %q\n", v.value)

	case ast.Var_Decl:
		fmt.sbprintf(b, "Var_Decl: %s\n", v.name)

		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Mut: %t\n", v.is_mut)

		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Kind: %s\n", v.init_kind)

		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Type: %v\n", v.type_info)

		if v.init_expr != nil {
			write_indent(b, indent + 1)
			strings.write_string(b, "Init:\n")
			write_node(b, v.init_expr, indent + 2)
		}

	case ast.If_Stmt:
		strings.write_string(b, "If_Stmt:\n")

		write_indent(b, indent + 1)
		strings.write_string(b, "Condition:\n")
		write_node(b, v.condition, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Body:\n")
		write_node(b, v.body, indent + 2)

		if v.else_stmt != nil {
			write_indent(b, indent + 1)
			strings.write_string(b, "Else:\n")
			write_node(b, v.else_stmt, indent + 2)
		}

	case ast.Break_Stmt:
		strings.write_string(b, "Break_Stmt\n")

	case ast.Continue_Stmt:
		strings.write_string(b, "Continue_Stmt\n")

	case ast.For_Stmt:
		switch v.kind {
		case .Infinite:
			strings.write_string(b, "For_Stmt (Infinite):\n")
			write_node(b, v.body, indent + 1)

		case .Each:
			strings.write_string(b, "For_Stmt (Each):\n")

			write_indent(b, indent + 1)
			fmt.sbprintf(b, "value: %s\n", v.iter_value_name.name)

			if v.iter_index_name.name != "" {
				write_indent(b, indent + 1)
				fmt.sbprintf(b, "index: %s\n", v.iter_index_name.name)
			}

			write_indent(b, indent + 1)
			strings.write_string(b, "iterable:\n")
			write_node(b, v.iter_expr, indent + 2)

			write_indent(b, indent + 1)
			strings.write_string(b, "body:\n")
			write_node(b, v.body, indent + 2)

		case .C_Style:
			strings.write_string(b, "For_Stmt (C-Style):\n")

			write_indent(b, indent + 1)
			strings.write_string(b, "init:\n")
			write_node(b, v.init, indent + 2)

			write_indent(b, indent + 1)
			strings.write_string(b, "condition:\n")
			write_node(b, v.condition, indent + 2)

			write_indent(b, indent + 1)
			strings.write_string(b, "post:\n")
			write_node(b, v.post, indent + 2)

			write_indent(b, indent + 1)
			strings.write_string(b, "body:\n")
			write_node(b, v.body, indent + 2)
		}

	case ast.Call:
		strings.write_string(b, "Call:\n")

		write_indent(b, indent + 1)
		strings.write_string(b, "Target:\n")
		write_node(b, v.target, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Arguments:\n")
		if v.args != nil {
			for arg in v.args^ {
				write_node(b, arg, indent + 2)
			}
		}

	case ast.Defer_Stmt:
		strings.write_string(b, "Defer_Stmt:\n")
		write_node(b, v.stmt, indent + 1)

	case ast.Return_Stmt:
		strings.write_string(b, "Return_Stmt:\n")
		if v.expr != nil {
			write_node(b, v.expr, indent + 1)
		}

	case ast.Array_Literal:
		strings.write_string(b, "Array_Literal:\n")
		if v.items != nil {
			for item in v.items^ {
				write_node(b, item, indent + 1)
			}
		}

	case ast.Struct_Literal:
		strings.write_string(b, "Struct_Literal:\n")

		write_indent(b, indent + 1)
		strings.write_string(b, "Type:\n")
		write_node(b, v.type, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Fields:\n")
		if v.fields != nil {
			for field in v.fields^ {
				node: ast.Spanned_AST = field
				write_node(b, &node, indent + 2)
			}
		} else {
			write_indent(b, indent + 2)
			strings.write_string(b, "<nil>\n")
		}

	case ast.Struct_Literal_Field:
		fmt.sbprintf(b, "Struct_Literal_Field: %s = ", v.name)
		if v.value != nil {
			strings.write_string(b, "\n")
			write_node(b, v.value, indent + 1)
		} else {
			strings.write_string(b, "<nil>\n")
		}

	case ast.Index_Expr:
		strings.write_string(b, "Index_Expr:\n")

		write_indent(b, indent + 1)
		strings.write_string(b, "Target:\n")
		write_node(b, v.target, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Index:\n")
		write_node(b, v.index, indent + 2)

	case ast.Slice_Expr:
		strings.write_string(b, "Slice_Expr:\n")

		write_indent(b, indent + 1)
		strings.write_string(b, "Target:\n")
		write_node(b, v.target, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "Start:\n")
		write_node(b, v.start, indent + 2)

		write_indent(b, indent + 1)
		strings.write_string(b, "End:\n")
		write_node(b, v.end, indent + 2)

	case ast.Cast_Expr:
		strings.write_string(b, "Cast_Expr:\n")
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Target_Type: %v\n", v.target_type)
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Is_Reinterpret: %t\n", v.is_reinterpret)
		write_indent(b, indent + 1)
		strings.write_string(b, "Expr:\n")
		write_node(b, v.expr, indent + 2)

	case ast.Field_Access:
		strings.write_string(b, "Field_Access:\n")
		write_node(b, v.target, indent + 1)
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Field: %s\n", v.field)

	case ast.Method_Call:
		strings.write_string(b, "Method_Call:\n")
		write_node(b, v.target, indent + 1)
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "Method: %s\n", v.method)
		write_indent(b, indent + 1)
		strings.write_string(b, "Arguments:\n")
		if v.args != nil {
			for arg in v.args^ {
				write_node(b, arg, indent + 2)
			}
		}
	}
}*/
