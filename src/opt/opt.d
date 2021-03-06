module opt.opt_manager;

import std.conv;

import opt.pass;
import opt.ssa_gen;

import logger;
import kir.ir_mod;
import kir.instr;

void optimise(IR_Module[] program, int level) {
	Optimisation_Pass[] passes;
	final switch (level) {
	case 0:
		// no opts!
		return;
	case 1:
		passes = [
			new SSA_Builder,
		]; // minimal passes
		break;
	}

	foreach (ref mod; program) {
		foreach (ref pass; passes) {
			logger.verbose(" - Performing optimisation pass '", to!string(pass), "''");
			pass.process(mod);
			if (VERBOSE_LOGGING) mod.dump();
		}
	}
}