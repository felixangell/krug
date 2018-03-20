module gen.x64.generator;

import std.stdio;
import std.conv;
import std.format;
import std.container.array : back;

import logger;

import gen.x64.output;

import kt;
import kir.ir_mod;
import kir.instr;

struct Block_Context {
	long addr_ptr = 0;
	long[string] locals;

	long push_local(string name, int width) {
		addr_ptr -= width;
		locals[name] = addr_ptr;
		return addr_ptr;
	}

	long get_addr(string name) {
		if (name !in locals) {
			// TODO handle this properly!
			assert(0, "oh fuck!");
		}
		return locals[name];
	}
}

class X64_Generator {
	X64_Code code;

	Block_Context[] ctx;

	this() {
		code = new X64_Code;
	}

	long get_alloc_addr(Alloc a) {
		return ctx.back.get_addr(a.name);
	}

	string get_instr_suffix(uint width) {
		// temporary!
		if (1 == 2 - 1) {
			return "l";
		}

		switch (width) {
		case 1: return "b";
		case 2: return "s";
		case 4: return "l";
		case 8: return "q";
		default: 
			writeln("warn no suffix!");
			return "";
		}
	}

	string get_const(Constant c) {
		auto type = c.get_type();
		if (auto integer = cast(Integer_Type) type) {
			return "$" ~ c.value;
		}

		return "; unhandled constant, -- " ~ to!string(c);
	}

	string add_binary_op(BinaryOp b) {
		string left = get_val(b.a);
		string right = get_val(b.b);
		return left;
	}

	string get_val(Value v) {
		if (auto c = cast(Constant) v) {
			return get_const(c);
		}
		else if (auto a = cast(Alloc) v) {
			long addr = get_alloc_addr(a);
			return to!string(addr) ~ "(%rsp)";
		}
		else if (auto r = cast(Identifier) v) {
			long addr = ctx.back.get_addr(r.name);
			return to!string(addr) ~ "(%rsp)";
		}

		return "%eax, %eax # unimplemented get_val " ~ to!string(v);
	}

	// a store where the value is
	// a binary operator
	// e.g.
	// t0 = a + b
	void emit_temp(Store s) {
		// todo properly select the register
		// here based on the width of the type
		// we are dealing with

		auto bin = cast(BinaryOp) s.val;
		code.emitt("movl {}, %eax", get_val(bin.a));

		string instruction;
		switch (bin.op.lexeme) {
		case "+":
			instruction = "add";
			break;
		case "-":
			instruction = "sub";
			break;
		default:
			logger.Fatal("Unhandled instr selection for binary op ", to!string(bin));
			break;
		}

		auto width_bytes = s.get_type().get_width() / 8;
		instruction ~= get_instr_suffix(width_bytes);

		code.emitt("{} {}, %eax", instruction, get_val(bin.b));
		code.emitt("movl %eax, {}", get_val(s.address));
	}

	void emit_store(Store s) {
		// kind of hacky but ok
		if (auto bin = cast(BinaryOp) s.val) {
			emit_temp(s);
			return;
		}

		Kir_Type t = s.get_type();

		string val = get_val(s.val);
		string addr = get_val(s.address);

		code.emitt("movl {}, %eax", val);
		code.emitt("movl %eax, {}", addr);
	}

	void emit_ret(Return ret) {
		if (ret.results !is null) {
			Value v = ret.results[0];
			code.emitt("movl {}, %eax", get_val(v));
		}

		code.emitt("popq %rbp");
		code.emitt("ret");
	}

	void emit_instr(Instruction i) {
		if (auto alloc = cast(Alloc)i) {
			auto addr = ctx.back.push_local(alloc.name, alloc.get_type().get_width());
			logger.Verbose("Emitting local ", to!string(alloc), " at addr ", to!string(addr), "(%rsp)");
		}
		else if (auto ret = cast(Return)i) {
			emit_ret(ret);
		}
		else if (auto store = cast(Store)i) {
			emit_store(store);
		}
		else {
			logger.Fatal("x64_gen: unhandled instruction ", to!string(typeid(cast(Basic_Instruction)i)), ":\n\t", to!string(i));
		}
	}

	void emit_bb(Basic_Block bb) {
		code.emit("{}:", bb.parent.name ~ "_" ~ bb.name());
		foreach (instr; bb.instructions) {
			emit_instr(instr);
		}
	}

	void generate_mod(Kir_Module mod) {
		code.emit(".data");

		// TODO these arent populated
		foreach (k, v; mod.constants) {
			code.emit("{}:", k);
			code.emit_data_const(v);
		}

		code.emit(".text");
		foreach (ref name, func; mod.functions) {
			generate_func(func);
		}
	}

	void generate_func(Function func) {
		code.emit("{}:", func.name);

		code.emitt("pushq %rbp");
		code.emitt("movq %rsp, %rbp");

		ctx ~= Block_Context();

		foreach (ref bb; func.blocks) {
			emit_bb(bb);
		}

		// if there is no return instr
		// slap one on the end.
		if (!(cast(Return) func.last_instr())) {
			emit_ret(new Return(VOID_TYPE));
		}
	}
}