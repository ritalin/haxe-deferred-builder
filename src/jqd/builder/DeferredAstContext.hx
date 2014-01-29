package jqd.builder;

import haxe.macro.Expr;

import jqd.builder.Statement;
import jqd.util.StringSet;

class DeferredAstContext {
	private var chains: Array<AsyncBlockChain>;
	private var lastChain: AsyncBlockChain;
	private var vars: Array<String>;

	public var depth(default, null): Int;
	public var varExcludes(default, null): StringSet;


	public function new(depth: Int = 1, varExcludes: StringSet) {
		this.chains = new Array<AsyncBlockChain>();
		this.depth = depth;
		this.varExcludes = varExcludes;
		this.vars = [];
	}

	public function nextChain(opt: AsyncOption): AsyncBlockChain {
		return this.lastChain = new AsyncBlockChain(opt);
	}

	public function pushChain(chain: AsyncBlockChain, expr: AsyncExpr, opt: AsyncOption): AsyncBlockChain {
		chain.pushAsyncExpr(expr);
		this.chains.push(chain);

		return this.nextChain(opt);
	}

	public function includeVarName(name: String): AsyncOption {
		if (! this.varExcludes.exists(name)) {
			this.vars.push(name);
		}

		return this.includeVars;
	}

	public var includeVars(get, null): AsyncOption;

	private function get_includeVars() {
		return this.vars.length > 0 ? OptVars(this.vars.slice(0)) : OptNone;
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