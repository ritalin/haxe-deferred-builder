package jqd.builder;

import haxe.macro.Expr;
import jqd.util.ImmutableEnumFlags;

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
	SAsyncLoop(factory: Expr -> Expr, ctx: DeferredAstContext);
	SAsyncReject(exception: Expr);
	SAsyncCatch(ctx: DeferredAstContext, pos: Position, catches: Array<AsyncCatchExpr>);
}

enum StatementContent {
	SSync(expr: Expr);
	SAsync(expr: AsyncExpr, opt: AsyncOption);
}

enum AsyncStatus {
	SResolveIgnored;
	SResolveAttached;
	SRejectIgnored;
	SRejectAttached;
}

typedef AsyncCatchExpr = {
	var ctx: DeferredAstContext;
	var type: ComplexType;
	var argName: String;
	var pos: Position;
}

typedef BuildResult = {
	var syncBlocks: Array<Expr>;
	var asyncExpr: Expr;
	var deadBlocks: Array<Expr>;
	var status: ImmutableEnumFlags<AsyncStatus>;
}
