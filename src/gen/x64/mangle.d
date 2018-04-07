module gen.x64.mangler;

import std.conv : to;
import std.traits : isInstanceOf;

import sema.type;
import kir.instr;

// NOTE
// M(x) means mangled form of x
// for example
// M(func) => mangled form of func
// M(word) => mangled form of word, i.e. 
// 			  M(foo) => 3foo

// length of word followed by the word
// for example
// 
// 11hello_world
// 3foo
// 5felix
string mangle(string word) {
	return to!string(word.length) ~ word;
}

string mangle_join(T...)(T values...) {
	string res;
	foreach (i, v; values) {
		if (i > 0) res ~= "_";
		res ~= mangle(v);
	}
	return res;
}

string mangle(Type t) {
	if (cast(Type_Operator) t) {
		// FIXME;
		return to!string(t);
	}
	else if (auto ptr = cast(Pointer) t) {
		return "p" ~ mangle(ptr.base);
	}
	else if (auto arr = cast(Array) t) {
		return "A" ~ mangle(arr.base);
	}

	return "unhandled_" ~ to!string(t);
}

string mangle(Alloc alloc) {
	return mangle(alloc.get_type());
}

string mangle(Alloc[] allocs...) {
	string result;
	foreach (i, alloc; allocs) {
		if (i > 0) result ~= "_";
		result ~= mangle(alloc);
	}
	return result;
}

string mangle(Label l) {
	return mangle(l.reference);
}

// M(module) + M(submodule) + M(func_name) + M(func_args...)
string mangle(Function f) {
	// even though this will probably have the
	// no_mangle attribute, we still mangle it
	if (f.has_attribute("c_func")) {
		return f.name;
	}

	if (f.has_attribute("no_mangle")) {
		return f.name;
	}
	
	return "__" ~ mangle_join!(string, string, Alloc[])(
		f.parent_mod.mod_name,
		f.name,
		f.params,
	);
}

string mangle(Basic_Block f) {
	return mangle_join!(Function, string)(
		f.parent,
		f.name(),
	);
}

unittest {

}