package jqd.builder;

import haxe.ds.Option;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;

import jqd.util.ImmutableEnumFlags;
import jqd.builder.Statement;

using Lambda;

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

	public function buildRootBlock(depth: Int, alwaysReturn: Bool, chains: Array<AsyncBlockChain>, lastChain: AsyncBlockChain): BuildResult {
		var dfdName = '_d${depth}';
		var inst = DeferredFactory.newInstExpr();

		var r = this.buildSubBlock(depth, dfdName, chains, lastChain, false);

		// When pass follow expression Array.cocat directly, this.resolved has always false, why?
		var exprs = r.asyncExpr != null ? [r.asyncExpr] : []; 		

		return {
			asyncExpr: null,
			syncBlocks: [ macro var $dfdName = $inst ]
				.concat(r.syncBlocks)
				.concat(exprs)
				.concat(r.status.any([SResolveAttached, SRejectAttached]) ? [ macro return $i{dfdName} ] : []),
			deadBlocks: [],
			status: r.status
		};
	}

	public function buildSubBlock(depth: Int, dfdName: String, chains: Array<AsyncBlockChain>, lastChain: AsyncBlockChain, acceptDeadBlocks: Bool): BuildResult {
		var r = buildSubBlockInternal(depth, dfdName, chains);

		if (r.asyncExpr == null) return r;

		var withResolved = lastChain.wrapResolve(depth, dfdName, true, r);
		var withRejected = this.wrapReject(depth, dfdName, withResolved);

		if (! acceptDeadBlocks && ! withResolved.deadBlocks.empty()) {
			Context.warning("Dead blocks Found.", withRejected.deadBlocks[0].pos);
		}

		return withRejected;
	}

	public function buildLoopBlock(depth: Int, arrName: String, alwaysReturn: Bool, chains: Array<AsyncBlockChain>, lastChain: AsyncBlockChain): ExprDef {
		var dfdName = '_d${depth}';
		var inst = DeferredFactory.newInstExpr();
		
		var r = this.buildSubBlock(depth, dfdName, chains, lastChain, true);

		return EBlock(
			[ macro var $dfdName = $inst ]
			.concat(r.syncBlocks)
			.concat(r.asyncExpr != null ? [r.asyncExpr] : [])
			.concat(r.deadBlocks)
			.concat(
				switch (this.asyncOption) {
				case OptReturn: [ macro return $i{dfdName} ];
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

	private function wrapResolve(depth: Int, dfdName: String, alwaysReturn: Bool, result: BuildResult): BuildResult {
		return
			if (result.status.any([SResolveIgnored])) {
				result.status = result.status.exclude([SResolveIgnored]);
				result;
			}
			else {
				{ 
					asyncExpr: this.buildAsyncCall(result.asyncExpr, this.buildResolveClosure(depth, dfdName, alwaysReturn)), 
					syncBlocks: result.syncBlocks, 
					deadBlocks: this.syncBlocks,
					status: result.status.include([SResolveAttached]),
				};
			}
		;
	}

	private function wrapReject(depth: Int, dfdName: String, result: BuildResult): BuildResult {
		return 
			if (result.status.any([SRejectIgnored])) {
				result.status = result.status.exclude([SRejectIgnored]);
				result;
			}
			else {
				{
					asyncExpr: buildAsyncCallInternal("fail", result.asyncExpr, this.buildRejectClosure(depth, dfdName, ['_tmp${depth}'])), 
					syncBlocks: result.syncBlocks, 
					deadBlocks: result.deadBlocks,
					status: result.status.include([SRejectAttached]),
				};
			}
	}

	private function foldAsyncExpr(result: BuildResult, depth: Int, dfdName: String): BuildResult {
		return 
			if (result == null) {
				switch(this.asyncExpr) {
				case Some(SAsyncCall(expr)):
					{ asyncExpr: expr, syncBlocks: this.syncBlocks, deadBlocks: [], status: ImmutableEnumFlags.of([]) };

				case Some(SAsyncExpr(expr)):
					{ 
						asyncExpr: macro return $i{dfdName}.resolve(${expr}), 
						syncBlocks: this.syncBlocks, deadBlocks: [], 
						status: ImmutableEnumFlags.of([SResolveIgnored, SRejectIgnored]),
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
						deadBlocks: [],
						status: ImmutableEnumFlags.of([]), // TODO: May be need to consider sub-block status
					};

				case Some(SAsyncLoop(factory, ctx)):
					this.buildParallelLoop(depth, ctx, factory);

				case Some(SAsyncReject(expr)):
					{ 
						asyncExpr: macro return $i{dfdName}.reject(${expr}), 
						syncBlocks: this.syncBlocks, deadBlocks: [],
						status: ImmutableEnumFlags.of([SResolveIgnored, SRejectIgnored]), 
					};	

				default:
					{ asyncExpr: null, syncBlocks: this.syncBlocks, deadBlocks: [], status: ImmutableEnumFlags.of([]) };
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
					result.status = result.status.set(SResolveIgnored);

				case Some(SAsyncBlock(ctx, p)):
					var r = ctx.buildRootBlock(p, true);
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosureInternal(extractClodureArgNames(depth, this.asyncOption), r.syncBlocks)
					);
					result.status = result.status.or(r.status);

				case Some(SAsyncLoop(factory, ctx)):
					var r = this.buildParallelLoop(depth, ctx, factory);
					var blocks = r.syncBlocks.concat(r.asyncExpr != null ? [r.asyncExpr] : []);

					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosureInternal(extractClodureArgNames(depth, this.asyncOption), blocks)
					);
					result.status = result.status.or(r.status);
				default:
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosure(depth, macro $i{dfdName}.reject())
					);
					result.status = result.status;
				}

				result;
			}
		;
	}

	public function buildParallelLoop(depth: Int, ctx: DeferredAstContext, factory: Expr->Expr): BuildResult {
		var pos = Context.currentPos();
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
		var loopBlocks = parallelResult.buildRootBlock(pos, true);

		var asyncExpr = this.buildAsyncCall(
			caller,
			this.buildClosureInternal(extractClodureArgNames(depth, this.asyncOption), loopBlocks.syncBlocks)
		);

		return { 
			asyncExpr: asyncExpr, 
			syncBlocks: 
				[ macro var $arrName = $holder ]
				.concat(syncBlocks)
				.concat([
					factory(ctx.buildLoopBlock(arrName, pos, true))
				]), 
			deadBlocks: [],
			status: loopBlocks.status,
		};
	}

	public function buildAsyncCall(receiver: Expr, arg: Expr): Expr {
		return buildAsyncCallInternal("then", receiver, arg);
	}

	private function buildAsyncCallInternal(methodName: String, receiver: Expr, arg: Expr): Expr {
        return {
            pos: receiver.pos,
            expr: ECall(
                { expr: EField(receiver, methodName), pos: Context.currentPos() }, 
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
		var closureExpr = this.syncBlocks.concat(caller != null ? [ macro return $caller ] : []);
		return buildClosureInternal(
        	extractClodureArgNames(depth, this.asyncOption), closureExpr
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
        	resolveId.argNames, [ closureExpr ]      
        );
	}

	private function buildRejectClosure(depth: Int, dfdName: String, argNames: Array<String>): Expr {
		var returns = argNames.map(function(arg) {
			return macro $i{arg};
		});

		var closureExpr = macro return $i{dfdName}.rejectWith($i{dfdName}, [$a{returns}]);

        return buildClosureInternal(
        	argNames, [ closureExpr ]      
        );
	}

    private function buildClosureInternal(argNames: Array<String>, blocksExpr: Array<Expr>): Expr {
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
                expr: { expr: EBlock(blocksExpr), pos: Context.currentPos() }  
            }),
            pos: Context.currentPos()
        };
    }
}