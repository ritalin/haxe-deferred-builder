package jqd.builder;

import haxe.macro.Expr;
import haxe.ds.Option;

import jqd.builder.Statement;
import jqd.util.StringSet;

using Lambda;

class DeferredAstVisitor {
	private static var META_ASYNC: String = ":async";

	private var fields: Array<Field>;

	public function new(fields: Array<Field>) {
		this.fields = fields;
	}

	/**
 	  * begin AST translation
 	  */
	public function process(): Array<Field> {
    	var results = new Array<Field>();

		for (field in this.fields) {
			// Skip non-async function declaration
			if (field.meta.exists(function(m) return m.name == META_ASYNC)) {
	    		switch (field.kind) {
	    		case FFun(fun):
	    			field.kind = FFun(processAsyncFunction(fun));
	    		default: 
	    		}    	
    		}

    		results.push(field);
    	}

	    return results;
	}

	/**
	  * process function AST
	  */
	public function processAsyncFunction(fun: Function): Function {
        switch (fun.expr) {
        case { expr: EBlock(blocks), pos: p }: 
        	var argNames = fun.args.map(function(arg) return arg.name);
        // trace(fun);
        	fun.expr = {
        		expr: EBlock(processAsyncBlocks(1, blocks, OptNone, StringSet.from(argNames), []).buildRootBlock(p, false).syncBlocks),
        		pos: p
        	};
        	
       	trace(new haxe.macro.Printer().printFunction(fun));
        default: 
        }

        return fun;
	}

	/**
	  * process block AST
	  */
	public function processAsyncBlocks(depth: Int, blockExprs: Array<Expr>, defaultOpt: AsyncOption, varExcludes: StringSet, varIncludes: Array<String>): DeferredAstContext {
		var ctx = new DeferredAstContext(depth, varExcludes, varIncludes);
		var chain = ctx.nextChain(defaultOpt);

		for (b in blockExprs) {
			switch (this.edxtractAsyncStatement(ctx, depth, b)) {
			case SSync(expr): 
				chain.pushSyncExpr(expr);
			case SAsync(expr, opt): 
				chain = ctx.pushChain(chain, expr, opt);
			}	
		}

//		trace(ctx);
		return ctx;
	}

	public function processCatchStatement(depth: Int): Catch -> AsyncCatchExpr {
		return function (c: Catch) {
			return 
				switch (c.expr) {
				case { expr: EBlock(blocks), pos: pos }:
					{
						ctx: this.processAsyncBlocks(depth, blocks, OptNone, new StringSet(), []),
						type: c.type,
						argName: c.name,
						pos: pos,
					};

				case { expr:_, pos:pos }:
					haxe.macro.Context.error("Unsupported catch statement.", pos);
					{
						ctx: null,
						type: c.type,
						argName: c.name,
						pos: pos,
					};
				}
			;
		}
	}

	private function edxtractAsyncStatement(ctx: DeferredAstContext, depth: Int, stmt: Expr): StatementContent {
		var extractInternal = function(meta: MetadataEntry, expr, opt, includeVars, nestRequired) {
	        return
		        switch (meta) {
		        case { name:":yield", params:_, pos:_ }: 
			        	if (nestRequired) { 
 			        		SAsync(
			        			SAsyncBlock(this.processAsyncBlocks(
				        			depth+1, 
				        			[stmt], 
				        			opt,
				        			new StringSet(),
				        			ctx.includeVars
				        		), stmt.pos),
				        		OptVars(includeVars)
				        	);
			        	}
			        	else {
			        		SAsync(this.extractAsyncStatementInternal(ctx, depth, expr), opt);
			        	}
		        default: 
		        	SSync(stmt);
		        }
		    ;			
		}

		return 
		    switch (stmt.expr) {
	        case EReturn({ expr: EMeta(meta, expr), pos:_ }) | EMeta(meta, { expr: EReturn(expr), pos:_ }):
	            extractInternal(meta, expr, OptReturn, ctx.includeVars, false);

	        case EMeta(meta, expr): 
	            extractInternal(meta, expr, OptNone, ctx.includeVars, ctx.hasChains);
	        
	        case EVars([{ expr: { expr: EMeta(meta, expr), pos:_ }, name: n, type:_ }]):
	            var result = extractInternal(meta, expr, OptVars([n]), ctx.includeVars.concat([n]), ctx.hasChains);
	        	ctx.includeVarName(n);

	            result;

	        default:    
	        	SSync(stmt);
	        }
		;
	}

	private function extractAsyncStatementInternal(ctx: DeferredAstContext, depth: Int, expr: Expr) {


		return
			switch (expr.expr) {
			case EParenthesis(e): 
				extractAsyncStatementInternal(ctx, depth, e);

			case EBlock(blocks):
				SAsyncBlock(this.processAsyncBlocks(depth+1, blocks, OptNone, new StringSet(), ctx.includeVars), expr.pos);

			case EFor(it, { expr: EBlock(blocks), pos: p }):
				SAsyncLoop(
					function(e) return { expr: EFor(it, e), pos: p }, 
					this.processAsyncBlocks(depth+1, blocks, OptNone, new StringSet(), ctx.includeVars)
				);

			case EWhile(cond, { expr: EBlock(blocks), pos: p }, normalWhile):
				SAsyncLoop(
					function(e) return { expr: EWhile(cond, e, normalWhile), pos: p }, 
					this.processAsyncBlocks(depth+1, blocks, OptNone, new StringSet(), ctx.includeVars)
				);

			case EThrow(exception):
				SAsyncReject(exception);

			case ETry({ expr: EBlock(blocks), pos: p}, catches):
				SAsyncCatch(
					this.processAsyncBlocks(depth+1, blocks, OptNone, new StringSet(), ctx.includeVars), p,
					catches.map(this.processCatchStatement(depth+2))
				);

			case ECall(_, _):
				SAsyncCall(expr);

			default:
				SAsyncExpr(expr);
			}
		;
	}
}