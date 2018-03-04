module sema.type_infer_pass;

import std.conv;
import std.stdio;

import logger;
import ast;
import sema.visitor;
import sema.analyzer : Semantic_Pass;
import sema.symbol;
import diag.engine;
import sema.type;
import krug_module;
import compiler_error;

class Type_Infer_Pass : Top_Level_Node_Visitor, Semantic_Pass {
	Module mod;

	override void analyze_named_type_node(ast.Named_Type_Node node) {

	}

	override void analyze_let_node(ast.Variable_Statement_Node var) {
		if (var.value !is null) {
			analyze_expr(var.value);
		}
	}

	override void analyze_function_node(ast.Function_Node node) {
		// some functions have no body!
		// these are prototype functions
		if (node.func_body !is null) {
			visit_block(node.func_body);
		}
	}

	void analyze_path_expr(ast.Path_Expression_Node path) {

	}

	void analyze_unary_unary(ast.Unary_Expression_Node unary) {

	}

	void analyze_expr(ast.Expression_Node expr) {
		if (auto binary = cast(ast.Binary_Expression_Node) expr) {
			analyze_binary_expr(binary);
		}
		else if (auto paren = cast(ast.Paren_Expression_Node) expr) {
			analyze_expr(paren.value);
		}
		else if (auto path = cast(ast.Path_Expression_Node) expr) {
			analyze_path_expr(path);
		}
		else if (auto call = cast(ast.Call_Node) expr) {
			analyze_call(call);
		}
		else if (auto unary = cast(ast.Unary_Expression_Node) expr) {
			analyze_unary_unary(unary);
		}
		else if (cast(ast.Integer_Constant_Node) expr) {
			// NOOP
		}
		else if (cast(ast.Float_Constant_Node) expr) {
			// NOOP
		}
		else if (cast(ast.String_Constant_Node) expr) {
			// NOOP
		}
		else {
			logger.Warn("name_resolve: unhandled node " ~ to!string(expr));
		}
	}

	void analyze_binary_expr(ast.Binary_Expression_Node binary) {
		analyze_expr(binary.left);
		analyze_expr(binary.right);
	}

	void analyze_while_stat(ast.While_Statement_Node while_loop) {
		analyze_expr(while_loop.condition);
		visit_block(while_loop.block);
	}

	void analyze_if_stat(ast.If_Statement_Node if_stat) {
		analyze_expr(if_stat.condition);
		visit_block(if_stat.block);
	}

	void analyze_call(ast.Call_Node call) {
		analyze_expr(call.left);
	}

	override void visit_stat(ast.Statement_Node stat) {
		if (auto variable = cast(ast.Variable_Statement_Node) stat) {
			analyze_let_node(variable);
		}
		else if (auto expr = cast(ast.Expression_Node) stat) {
			analyze_expr(expr);
		}
		else if (auto while_loop = cast(ast.While_Statement_Node) stat) {
			analyze_while_stat(while_loop);
		}
		else if (auto if_stat = cast(ast.If_Statement_Node) stat) {
			analyze_if_stat(if_stat);
		}
		else if (auto call = cast(ast.Call_Node) stat) {
			analyze_call(call);
		}
		else {
			logger.Warn("name_resolve: unhandled statement " ~ to!string(stat));
		}
	}

	override void execute(ref Module mod, string sub_mod_name) {
		assert(mod !is null);
		this.mod = mod;

		if (sub_mod_name !in mod.as_trees) {
			logger.Error("couldn't find the AST for " ~ sub_mod_name ~
					" in module " ~ mod.name ~ " ...");
			return;
		}

		// current = mod.scopes[sub_mod_name];
		curr_sym_table = mod.sym_tables[sub_mod_name];

		auto ast = mod.as_trees[sub_mod_name];
		foreach (node; ast) {
			if (node !is null) {
				super.process_node(node);
			}
		}
	}

	override string toString() const {
		return "top-level-type-decl-pass";
	}

}