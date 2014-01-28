package jqd.builder;

import haxe.macro.Expr;

import jqd.builder.Statement;

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
        	fun.expr = processAsyncBlocks(1, blocks).buildRootBlock(p);
        default: 
        }

        return fun;
	}

	/**
	  * process block AST
	  */
	public function processAsyncBlocks(depth: Int, blockExprs: Array<Expr>): DeferredAstContext {
		var ctx = new DeferredAstContext(depth);
		var chain = ctx.nextChain(AsyncOption.OptNone);

		for (b in blockExprs) {
			switch (this.edxtractAsyncStatement(depth, b)) {
			case SSync(expr): 
				chain.pushSyncExpr(expr);
			case SAsync(expr, opt): 
				chain = ctx.pushChain(chain, expr, opt);
			}	
		}

		return ctx;
	}

	private function edxtractAsyncStatement(depth: Int, stmt: Expr): StatementContent {
		var extractInternal = function(meta: MetadataEntry, expr, opt) {
	        return
		        switch (meta) {
		        case { name:":yield", params:_, pos:_ }: 
		        	SAsync(this.extractAsyncStatementInternal(depth, expr), opt);
		        default: 
		        	SSync(stmt);
		        }
		    ;			
		}

		return 
		    switch (stmt.expr) {
	        case EMeta(meta, expr): 
	            extractInternal(meta, expr, OptNone);
	        
	        case EVars([{ expr: { expr: EMeta(meta, expr), pos:_ }, name: n, type:_ }]):
	            extractInternal(meta, expr, OptVar(n));

	        case EReturn({ expr: EMeta(meta, expr), pos:_ }):
	            extractInternal(meta, expr, OptReturn);

	        default:    
	        	SSync(stmt);
	        }
		;
	}

	private function extractAsyncStatementInternal(depth: Int, expr: Expr) {
		return
			switch (expr.expr) {
			case EParenthesis(e): 
				extractAsyncStatementInternal(depth, e);

			case EBlock(blocks):
				SAsyncBlock(this.processAsyncBlocks(depth+1, blocks), expr.pos);

			case ECall(_, _):
				SAsyncCall(expr);

			default:
				SAsyncExpr(expr);
			}
		;
	}
}