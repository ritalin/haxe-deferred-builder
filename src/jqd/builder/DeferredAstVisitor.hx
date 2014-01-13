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
        	fun.expr = processAsyncBlocks(new DeferredAstContext(), blocks).buildBlock(p);

        default: 
        }

        return fun;
	}

	/**
	  * process block AST
	  */
	public function processAsyncBlocks(ctx: DeferredAstContext, blockExprs: Array<Expr>): DeferredAstContext {

		for (b in blockExprs) {
			switch (this.edxtractAsyncStatement(b)) {
			case SSync(expr): 
				ctx.pushSyncExpr(expr);
			case SAsync(expr, opt): 
				ctx.pushAsyncExpr(expr, opt);
			}	
		}

		return ctx;
	}

	private function edxtractAsyncStatement(stmt: Expr): StatementContent {
		var extractInternal = function(meta: MetadataEntry, expr, opt) {
	        return
		        switch (meta) {
		        case { name:":yield", params:_, pos:_ }: this.edxtractAsyncStatementInternal(expr, opt);
		        default: SSync(stmt);
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

	private function edxtractAsyncStatementInternal(expr: Expr, opt: AsyncOption) {
		return
			switch (expr.expr) {
			case EParenthesis(e): 
				edxtractAsyncStatementInternal(e, opt);
			default:
				SAsync(expr, opt);
			}
		;
	}
}