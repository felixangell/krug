module kir.ir_mod;

import std.conv;
import std.stdio;
import std.container.array : back;

import kir.instr;

class Kir_Module {
	Function[] functions;

	Value[string] constants;

	Function current_func() {
		return functions.back;
	}

	Function add_function(string name) {
		auto func = new Function();
		func.name = name;
		functions ~= func;
		return func;
	}

	void dump() {
		foreach (entry; constants.byKeyValue()) {
			writeln("'" ~ entry.key, " = ", to!string(entry.value));
		}
		writeln;

		foreach (i, func; functions) {
			if (i > 0)
				write('\n');
			func.dump();
		}
	}
}
