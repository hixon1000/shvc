package parser

import "ast"
import "core:fmt"

debug_ast_print :: proc(result: Parse_Result) {
	fmt.println("=== AST DUMP ===")
	print_node(result.root, 0)
	fmt.println("================")
}

print_indent :: proc(indent: int) {
	for _ in 0 ..< indent {
		fmt.print("  ")
	}
}

// standard recursive type
print_node :: proc(node: ^ast.AST_Node, indent: int) {
	if node == nil {
		print_indent(indent)
		fmt.println("<nil>")
		return
	}

	print_indent(indent)

	switch v in node^ {
	case ast.Program:
		fmt.println("Program:")
		if v.statements.items != nil {
			for stmt in v.statements.items^ {
				print_node(stmt, indent + 1)
			}
		}

	case ast.Block:
		fmt.println("Block:")
		if v.items != nil {
			for stmt in v.items^ {
				print_node(stmt, indent + 1)
			}
		}

	case ast.Fn_Decl:
		fmt.printf("Fn_Decl: %s\n", v.name)

		print_indent(indent + 1)
		fmt.print("Args: [")
		if v.args != nil {
			for arg, i in v.args^ {
				if i > 0 do fmt.print(", ")
				if arg.is_mut do fmt.print("mut ")
				fmt.printf("%s: %v", arg.name, arg.type)
			}
		}
		fmt.println("]")

		print_indent(indent + 1)
		fmt.printf("Returns: %v\n", v.ret_type)

		if v.body != nil {
			print_indent(indent + 1)
			fmt.println("Body:")
			if v.body.items != nil {
				for stmt in v.body.items^ {
					print_node(stmt, indent + 2)
				}
			}
		}

	case ast.Struct_Decl:
		fmt.printf("Struct_Decl: %s\n", v.name)

		print_indent(indent + 1)
		fmt.print("Fields: [")
		if v.fields != nil {
			for field, i in v.fields^ {
				if i > 0 do fmt.print(", ")
				fmt.printf("%s: %v", field.name, field.type)
			}
		}
		fmt.println("]")

	case ast.Trait_Decl:
		fmt.printf("Trait_Decl: %s\n", v.name)

		if v.methods != nil {
			print_indent(indent + 1)
			fmt.println("Methods:")

			for method in v.methods^ {
				method_node: ast.AST_Node = method
				print_node(&method_node, indent + 2)
			}
		}

	case ast.Binary_Op:
		fmt.printf("Binary_Op: %v\n", v.op)
		print_node(v.left, indent + 1)
		print_node(v.right, indent + 1)

	case ast.Unary_Op:
		fmt.printf("Unary_Op: %v\n", v.op)
		print_node(v.operand, indent + 1)

	case ast.Identifier:
		fmt.printf("Identifier: %s\n", v.name)

	case ast.Int_Literal:
		fmt.printf("Int_Literal: %d\n", v.value)

	case ast.Float_Literal:
		fmt.printf("Float_Literal: %f\n", v.value)

	case ast.String_Literal:
		fmt.printf("String_Literal: %q\n", v.value)

	case ast.Var_Decl:
		fmt.printf("Var_Decl: %s\n", v.name)

		print_indent(indent + 1)
		fmt.printf("Mut: %t\n", v.is_mut)

		print_indent(indent + 1)
		fmt.printf("Kind: %s\n", v.init_kind)

		print_indent(indent + 1)
		fmt.printf("Type: %v\n", v.type_info)

		if v.init_expr != nil {
			print_indent(indent + 1)
			fmt.println("Init:")
			print_node(v.init_expr, indent + 2)
		}

	case ast.If_Stmt:
		fmt.println("If_Stmt:")

		print_indent(indent + 1)
		fmt.println("Condition:")
		print_node(v.condition, indent + 2)

		print_indent(indent + 1)
		fmt.println("Body:")
		print_node(v.body, indent + 2)

		if v.else_stmt != nil {
			print_indent(indent + 1)
			fmt.println("Else:")
			print_node(v.else_stmt, indent + 2)
		}

	case ast.For_Loop:
		fmt.println("For_Loop:")
		print_node(v.init, indent + 1)
		print_node(v.cond, indent + 1)
		print_node(v.step, indent + 1)
		if v.body != nil && v.body.items != nil {
			print_indent(indent + 1)
			fmt.println("Body:")
			for stmt in v.body.items^ {
				print_node(stmt, indent + 2)
			}
		}

	case ast.Call:
		fmt.println("Call:")

		print_indent(indent + 1)
		fmt.println("Target:")
		print_node(v.target, indent + 2)

		print_indent(indent + 1)
		fmt.println("Arguments:")
		if v.args != nil {
			for arg in v.args^ {
				print_node(arg, indent + 2)
			}
		}

	case ast.Defer_Stmt:
		fmt.println("Defer_Stmt:")
		print_node(v.stmt, indent + 1)

	case ast.Return_Stmt:
		fmt.println("Return_Stmt:")
		if v.expr != nil {
			print_node(v.expr, indent + 1)
		}

	case ast.Array_Literal:
		fmt.println("Array_Literal:")
		if v.items != nil {
			for item in v.items^ {
				print_node(item, indent + 1)
			}
		}

	case ast.Index_Expr:
		fmt.println("Index_Expr:")

		print_indent(indent + 1)
		fmt.println("Target:")
		print_node(v.target, indent + 2)

		print_indent(indent + 1)
		fmt.println("Index:")
		print_node(v.index, indent + 2)

	case ast.Slice_Expr:
		fmt.println("Slice_Expr:")

		print_indent(indent + 1)
		fmt.println("Target:")
		print_node(v.target, indent + 2)

		print_indent(indent + 1)
		fmt.println("Start:")
		print_node(v.start, indent + 2)

		print_indent(indent + 1)
		fmt.println("End:")
		print_node(v.end, indent + 2)

	case ast.Cast_Expr:
		fmt.println("Cast_Expr:")
		print_indent(indent + 1)
		fmt.printf("Target_Type: %v\n", v.target_type)
		print_indent(indent + 1)
		fmt.printf("Is_Reinterpret: %t\n", v.is_reinterpret)
		print_indent(indent + 1)
		fmt.println("Expr:")
		print_node(v.expr, indent + 2)

	case ast.Field_Access:
		fmt.println("Field_Access:")
		print_node(v.target, indent + 1)
		print_indent(indent + 1)
		fmt.printf("Field: %s\n", v.field)

	case ast.Method_Call:
		fmt.println("Method_Call:")
		print_node(v.target, indent + 1)
		print_indent(indent + 1)
		fmt.printf("Method: %s\n", v.method)
		print_indent(indent + 1)
		fmt.println("Arguments:")
		if v.args != nil {
			for arg in v.args^ {
				print_node(arg, indent + 2)
			}
		}
	}
}
