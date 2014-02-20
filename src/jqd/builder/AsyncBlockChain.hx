package jqd.builder;

import haxe.ds.Option;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;

import jqd.builder.Statement;

typedef BuildResult = {
	var syncBlocks: Array<Expr>;
	var asyncExpr: Expr;
	var resolved: Bool;
}

private typedef ResolveIdentifier = {
	var argNames: Array<String>;
	var resolveVars: Array<String>;
}

class AsyncBlockChain {
	private var syncBlocks: Array<Expr>;
	private var asyncExpr: Option<AsyncExpr>;
	private var asyncOption: AsyncOption;
	private var resolveVars: Array<String>;


	public function new(opt: AsyncOption) {
		this.asyncOption = opt;
		this.syncBlocks = new Array<Expr>();
		this.asyncExpr = None;
		this.resolveVars = [];
	}

	public function pushSyncExpr(expr: Expr): Void {
		this.syncBlocks.push(expr);
	}

	public function pushAsyncExpr(expr: AsyncExpr, resolveVars: Array<String>): AsyncBlockChain {
		this.asyncExpr = Some(expr);
		this.resolveVars = this.resolveVars.concat(resolveVars);

		return this;
	}

	public function buildRootBlock(depth: Int, alwaysReturn: Bool, chains: Array<AsyncBlockChain>, lastChain: AsyncBlockChain): Array<Expr> {
		var dfdName = '_d${depth}';
		var inst = DeferredFactory.newInstExpr();

		var r = this.buildSubBlockInternal(depth, dfdName, chains);

		// When pass follow expression Array.cocat directly, this.resolved has always false, why?
		var exprs = if (r.asyncExpr == null) { 
			[];
		}
		else {
			[lastChain.wrapResolve(depth, dfdName, alwaysReturn, r)];
		}		

		return 
			[ macro var $dfdName = $inst ]
			.concat(r.syncBlocks)
			.concat(exprs)
			.concat(r.resolved ? [] : [ macro return $i{dfdName} ])
		;
	}

	public function buildSubBlock(depth: Int, dfdName: String, chains: Array<AsyncBlockChain>, lastChain: AsyncBlockChain): BuildResult {
		var r = buildSubBlockInternal(depth, dfdName, chains);

		if (r.asyncExpr != null) {
			r.asyncExpr = lastChain.wrapResolve(depth, dfdName, true, r);
		}

		return r;
	}

	public function buildLoopBlock(depth: Int, arrName: String, alwaysReturn: Bool, chains: Array<AsyncBlockChain>, lastChain: AsyncBlockChain): ExprDef {
		var dfdName = '_d${depth}';
		var inst = DeferredFactory.newInstExpr();
		
		var r = this.buildSubBlock(depth, dfdName, chains, lastChain);

		return EBlock(
			[ macro var $dfdName = $inst ]
			.concat(r.syncBlocks)
			.concat(r.asyncExpr != null ? [r.asyncExpr] : [])
			.concat(
				switch (this.asyncOption) {
				case OptReturn: [];
				default: [ macro $i{arrName}.push($i{dfdName}) ];
				}
			)
		);	
	}

	public function buildSubBlockInternal(depth: Int, dfdName: String, chains: Array<AsyncBlockChain>): BuildResult {
		var r = this.foldAsyncExpr(null, depth, dfdName);

		for (c in chains) {
			r = c.foldAsyncExpr(r, depth, dfdName);
		}

		return r;
	}

	private function wrapResolve(depth: Int, dfdName: String, alwaysReturn: Bool, result: BuildResult): Expr {
		return
			if (result.resolved) {
				result.asyncExpr;
			}
			else {
				this.buildAsyncCall(result.asyncExpr, this.buildResolveClosure(depth, dfdName, alwaysReturn));
			}
		;
	}

	private function foldAsyncExpr(result: BuildResult, depth: Int, dfdName: String): BuildResult {
		return 
			if (result == null) {
				switch(this.asyncExpr) {
				case Some(SAsyncCall(expr)):
					{ asyncExpr: expr, syncBlocks: this.syncBlocks, resolved: false };

				case Some(SAsyncExpr(expr)):
					{ 
						asyncExpr: macro return $i{dfdName}.resolve(${expr}), 
						syncBlocks: this.syncBlocks, resolved: true 
					};			

				case Some(SAsyncBlock(ctx, p)):
					var subDfdName = '_d${ctx.depth}';
					var inst = DeferredFactory.newInstExpr();

					var blocks = this.syncBlocks
						.concat([ macro var $subDfdName = $inst ])
						.concat([ ctx.buildSubBlock(subDfdName, p) ])
					;

					{ 
						asyncExpr: macro $i{subDfdName}, 
						syncBlocks: blocks, 
						resolved: false 
					};

				case Some(SAsyncFor(it, ctx, p)):
					this.buildParallelForLoop(depth, ctx, it, p);

				default:
					{ asyncExpr: null, syncBlocks: this.syncBlocks, resolved: false };
				}	
			}
			else {
				switch(this.asyncExpr) {
				case Some(SAsyncCall(expr)):
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosure(depth, expr)
					);

				case Some(SAsyncExpr(expr)):
					var asyncExpr = macro $i{dfdName}.resolve(${expr});
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosure(depth, asyncExpr)
					);
					result.resolved = true;

					result;

				case Some(SAsyncBlock(ctx, p)):
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosureInternal(extractClodureArgNames(depth, this.asyncOption), ctx.buildRootBlock(p, true))
					);

				case Some(SAsyncFor(it, ctx, p)):
					var r = this.buildParallelForLoop(depth, ctx, it, p);
					var blocks = r.syncBlocks.concat(r.asyncExpr != null ? [r.asyncExpr] : []);

					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosureInternal(extractClodureArgNames(depth, this.asyncOption), { expr: EBlock(blocks), pos: Context.currentPos() })
					);

				default:
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosure(depth, macro $i{dfdName}.reject())
					);
					result.resolved = true;
				}

				result;
			}
		;
	}

	public function buildParallelForLoop(depth: Int, ctx: DeferredAstContext, iterate: Expr, pos: Position): BuildResult {
		var arrName = "_da";
		var clz = DeferredFactory.parallelClass();
		var holder = DeferredFactory.newParallelHolder();

		var parallelResult = new DeferredAstContext(depth+1, new jqd.util.StringSet(), []);
		parallelResult.pushChain(
			parallelResult.nextChain(OptNone), 
			SAsyncExpr(DeferredFactory.getParallelResults()), 
			OptReturn
		);

		var caller = macro $clz.when.apply($clz, $i{arrName});
		var asyncExpr = this.buildAsyncCall(
			caller,
			this.buildClosureInternal(extractClodureArgNames(depth, this.asyncOption), parallelResult.buildRootBlock(pos, true))
		);

		return { 
			asyncExpr: asyncExpr, 
			syncBlocks: 
				[ macro var $arrName = $holder ]
				.concat([{ 
					expr: EFor(iterate, ctx.buildLoopBlock(arrName, pos, true)), pos: pos
				}]), 
			resolved: false 
		};
	}

	public function buildAsyncCall(receiver: Expr, arg: Expr): Expr {
        return {
            pos: receiver.pos,
            expr: ECall(
                { expr: EField(receiver, "then"), pos: Context.currentPos() }, 
                [arg]
            )
        };
	}

	private function extractClodureArgNames(depth: Int, opt: AsyncOption): Array<String> {
		return
			switch(opt) {
			case OptVars(name): name;
			case OptReturn: ['_return${depth}'];
			default: [];
			}
		;	
	}

	private function buildClosure(depth: Int, caller) {
		return buildClosureInternal(
        	extractClodureArgNames(depth, this.asyncOption),
            {
                pos: Context.currentPos(),
                expr: EBlock(this.syncBlocks.concat(caller != null ? [ macro return $caller ] : []))
            }
        );		
	}

	private function buildResolveClosure(depth: Int, dfdName: String, alwaysReturn: Bool) {
		var resolveNone = function(): ResolveIdentifier return { argNames: [], resolveVars: [] };
		var resolveId: ResolveIdentifier = 
			switch(this.asyncOption) {
			case OptNone: 
				alwaysReturn ? { argNames: ['_tmp${depth}'], resolveVars: this.resolveVars } : resolveNone();

			case OptVars(names): alwaysReturn ? { argNames: names, resolveVars: this.resolveVars } : resolveNone();
			case OptReturn: 
				var name = '_return${depth}';
				{ argNames: [name], resolveVars: [name] };
			}
		;

		var returns = resolveId.resolveVars.map(function(arg) {
			return macro $i{arg};
		});

		var closureExpr = macro return $i{dfdName}.resolveWith($i{dfdName}, [$a{returns}]);

        return buildClosureInternal(
        	resolveId.argNames,
            {
                pos: Context.currentPos(),
                expr: EBlock(this.syncBlocks.concat([ closureExpr ]))
            }        
        );
	}

    private function buildClosureInternal(argNames: Array<String>, blocksExpr: Expr): Expr {
        var args = argNames.map(function(name) {
			return { 
	            name: name, 
	            type: TPath({ name: "Dynamic", pack: [], params: [] }), 
	            opt: false, value: null 
	        };
        });

        return {
            expr: EFunction(null, {
                args: args, 
                params: [], 
                ret: null,
                expr: blocksExpr
            }),
            pos: Context.currentPos()
        };
    }
}