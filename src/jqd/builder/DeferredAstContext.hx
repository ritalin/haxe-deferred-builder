package jqd.builder;

import haxe.macro.Expr;
import haxe.ds.Option;

import jqd.builder.Statement;
import jqd.util.StringSet;

using Lambda;

class DeferredAstContext {
	public var chains(default, null): Array<AsyncBlockChain>;
	private var lastChain: AsyncBlockChain;
	private var vars: Array<String>;

	public var depth(default, null): Int;
	public var varExcludes(default, null): StringSet;


	public function new(depth: Int = 1, varExcludes: StringSet, varIncludes: Array<String>) {
		this.chains = new Array<AsyncBlockChain>();
		this.depth = depth;
		this.varExcludes = varExcludes;
		this.vars = varIncludes.slice(0);
	}

	public function nextChain(opt: AsyncOption): AsyncBlockChain {
		return this.lastChain = new AsyncBlockChain(opt);
	}

	public function pushChain(chain: AsyncBlockChain, expr: AsyncExpr, opt: AsyncOption): AsyncBlockChain {
		this.chains.push(
			chain.pushAsyncExpr(expr, this.includeVars)
		);

		return this.nextChain(opt);
	}

	public var hasChains(get, never): Bool;

	private function get_hasChains() {
		return this.chains.length > 0;
	}

	public function includeVarName(name: String): Void {
		if ((! this.varExcludes.exists(name)) && (! this.vars.has(name))) {
			this.vars.push(name);
		}
	}

	public var includeVars(get, null): Array<String>;

	private function get_includeVars() {
		return this.vars.slice(0);
	}

	public function buildRootBlock(p: Position, alwaysReturn: Bool): Expr {

		// trace(this.chains);
		 trace(this.lastChain.pushAsyncExpr(SAsyncBlank, this.includeVars));

		return { 
			expr: EBlock(this.chains[0].buildRootBlock(
				this.depth, alwaysReturn, 
				this.chains.slice(1), this.lastChain)),
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