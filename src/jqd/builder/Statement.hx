package jqd.builder;

import haxe.macro.Expr;

enum AsyncOption {
	OptNone;
	OptVars(varNames: Array<String>);
	OptReturn;
}

enum AsyncExpr {
	SAsyncBlank;
	SAsyncExpr(expr: Expr);
	SAsyncCall(expr: Expr);
	SAsyncBlock(ctx: DeferredAstContext, pos: Position);
}

enum StatementContent {
	SSync(expr: Expr);
	SAsync(expr: AsyncExpr, opt: AsyncOption);
}