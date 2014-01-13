package jqd.builder;

import haxe.macro.Expr;

enum AsyncOption {
	OptNone;
	OptVar(varName: String);
	OptReturn;
}

enum StatementContent {
	SSync(expr: Expr);
	SAsync(expr: Expr, opt: AsyncOption);
}
