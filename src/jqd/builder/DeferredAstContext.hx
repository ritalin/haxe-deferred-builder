package jqd.builder;

import haxe.macro.Expr;

import jqd.builder.Statement;

class DeferredAstContext {
	private var currentBlock: AsyncBlockChain;
	private var depth: Int;

	public function new(depth: Int = 1) {
		this.currentBlock = new AsyncBlockChain(AsyncOption.OptNone);
		this.depth = depth;
	}

	public function pushSyncExpr(expr: Expr): Void {
		this.currentBlock.pushSyncExpr(expr);
	}

	public function pushAsyncExpr(expr: Expr, opt: AsyncOption): Void {
		this.currentBlock = this.currentBlock.newChain(expr, opt);
	}

	public function buildBlock(p: Position): Expr {
		return { expr: EBlock(this.currentBlock.buildBlockExpr(this.depth)), pos: p };
	}
}