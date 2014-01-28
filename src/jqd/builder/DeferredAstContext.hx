package jqd.builder;

import haxe.macro.Expr;

import jqd.builder.Statement;

class DeferredAstContext {
	private var chains: Array<AsyncBlockChain>;
	private var lastChain: AsyncBlockChain;
	public var depth(default, null): Int;

	public function new(depth: Int = 1) {
		this.chains = new Array<AsyncBlockChain>();
		this.depth = depth;
	}

	public function nextChain(opt: AsyncOption): AsyncBlockChain {
		return this.lastChain = new AsyncBlockChain(opt);
	}

	public function pushChain(chain: AsyncBlockChain, expr: AsyncExpr, opt: AsyncOption): AsyncBlockChain {
		chain.pushAsyncExpr(expr);
		this.chains.push(chain);

		return this.nextChain(opt);
	}

	public function buildRootBlock(p: Position): Expr {
		return { 
			expr: EBlock(this.chains[0].buildRootBlock(this.depth, this.chains.slice(1), this.lastChain)),
			pos: p 
		};
	}

	public function buildSubBlock(dfdName: String, p: Position): Expr {
		var result = this.chains[0].buildSubBlock(this.depth, dfdName, this.chains.slice(1), this.lastChain);
		return {
			expr: EBlock(result.syncBlocks.concat(result.asyncExpr != null ? [result.asyncExpr] : [])),
			pos: p
		};
	}
}