package jqd.builder;

import haxe.macro.Expr;

import jqd.builder.Statement;

class DeferredAstContext {
	private var chains: Array<AsyncBlockChain>;
	private var depth: Int;

	public function new(depth: Int = 1) {
		this.chains = new Array<AsyncBlockChain>();
		this.depth = depth;
	}

	public function nextChain(opt: AsyncOption): AsyncBlockChain {
		var chain = new AsyncBlockChain(opt);
		this.chains.push(chain);

		return chain;
	}

	public function pushChain(chain: AsyncBlockChain, expr: AsyncExpr, opt: AsyncOption): AsyncBlockChain {
		chain.pushAsyncExpr(expr);

		return this.nextChain(opt);
	}

	public function buildRootBlock(p: Position): Expr {

		return { 
			expr: EBlock(this.chains[0].buildRootBlock(this.depth, this.chains.slice(1, -1))),
			pos: p 
		};
	}

	public function buildSubBlock(dfdName: String, p: Position): Void {
	}
}