import std.stdio;
import std.datetime;
import std.conv;
import std.array;
import std.algorithm.sorting;
import std.parallelism;
import std.getopt;

import colour;
import ds.hash_set;
import dependency_scanner;
import krug_module;

import parse.parser;
import ast;
import err_logger;

import sema.analyzer;

uint OPTIMIZATION_LEVEL = 1;
const VERSION = "0.0.1";
const KRUG_EXT = ".krug";

void main(string[] args) {
    StopWatch compilerTimer;
    compilerTimer.start();

    // argument stuff.
    getopt(args,
        "no-colours", "disables colourful output logging", &colour.NO_COLOURS,
        "verbose|v", "enable verbose logging", &err_logger.VERBOSE_LOGGING,
        "opt|O", "optimization level", &OPTIMIZATION_LEVEL,
    );

    // argument validation
    {
        if (OPTIMIZATION_LEVEL < 1 || OPTIMIZATION_LEVEL > 3) {
            err_logger.Error("optimization level must be between 1 and 3.");
        }
    }

    if (err_logger.VERBOSE_LOGGING) {
        err_logger.Verbose();
        err_logger.Verbose("KRUG COMPILER, VERSION " ~ VERSION);
        err_logger.Verbose("Executing compiler, optimization level O" ~ to!string(OPTIMIZATION_LEVEL));
        err_logger.Verbose();
        writeln();
    }

	if (args.length == 1) {
        err_logger.Error("no input file.");
	    return;
	}

    auto main_source_file = new Source_File(args[1]);
    Krug_Project proj = build_krug_project(main_source_file);
    assert("main" in proj.graph);

    // TODO: we can move flatten -> sort into
    // one thing instead of a two step solution!

    // flatten the dependency graph into an array
    // of modules.
    Dependency_Graph graph = proj.graph;
    Module*[] flattened;
    foreach (ref mod; graph) {
        flattened ~= &mod;
    }

    // sort the flattened modules such that the
    // modules with the least amount of dependencies
    // are first
    auto sorted_deps = flattened.sort!((a, b) => a.dep_count() < b.dep_count());
    err_logger.Verbose("Parsing: ");
    foreach (ref dep; sorted_deps) {
        auto tok_streams = dep.token_streams;
        foreach (ref entry; tok_streams.byKeyValue) {
            err_logger.Verbose("- " ~ dep.name ~ "::" ~ entry.key);
            dep.as_trees[entry.key] = new Parser(entry.value).parse();
        }
    }

    err_logger.Verbose("Performing semantic analysis on: ");
    foreach (ref dep; sorted_deps) {
        auto as_trees = dep.as_trees;
        auto sema = new Semantic_Analysis(graph);
        foreach (ref entry; as_trees.byKeyValue) {
            sema.process(entry.value, dep.name, entry.key);
        }
    }

	auto duration = compilerTimer.peek();
	err_logger.Info("Compiler took "
	    ~ to!string(duration.msecs)
	    ~ "/ms or "
	    ~ to!string(duration.usecs)
	    ~ "/µs");
}