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

class AsyncBlockChain {
	private var syncBlocks: Array<Expr>;
	private var asyncExpr: Option<AsyncExpr>;
	private var asyncOption: AsyncOption;


	public function new(opt: AsyncOption, ?next: AsyncBlockChain) {
		this.asyncOption = opt;
		this.syncBlocks = new Array<Expr>();
		this.asyncExpr = None;
	}

	public function pushSyncExpr(expr: Expr): Void {
		this.syncBlocks.push(expr);
	}

	public function pushAsyncExpr(expr: AsyncExpr): Void {
		this.asyncExpr = Some(expr);
	}

	public function buildRootBlock(depth: Int, chains: Array<AsyncBlockChain>): Array<Expr> {
		var dfdName = '_d${depth}';
		var inst = DeferredFactory.newInstExpr();

		var r = this.buildSubBlockInternal(depth, dfdName, chains);

		// When pass follow expression Array.cocat directly, this.resolved has always false, why?
		var exprs = if (r.asyncExpr == null) { 
			[];
		}
		else {
			[this.wrapResolve(depth, dfdName, r)];
		}		

		return new Array<Expr>()
			.concat([ macro var $dfdName = $inst ])
			.concat(r.syncBlocks)
			.concat(exprs)
			.concat(r.resolved ? [] : [ macro return $i{dfdName} ])
		;
	}

	public function buildSubBlock(depth: Int, dfdName: String, chains: Array<AsyncBlockChain>): BuildResult {
		var r = buildSubBlockInternal(depth, dfdName, chains);

		if (r.asyncExpr != null) {
			r.asyncExpr = this.wrapResolve(depth, dfdName, r);
		}

		return r;
	}

	public function buildSubBlockInternal(depth: Int, dfdName: String, chains: Array<AsyncBlockChain>): BuildResult {
		var r = this.foldAsyncExpr(null, depth, dfdName);

		for (c in chains) {
			r = c.foldAsyncExpr(r, depth, dfdName);
		}

		return r;
	}

	private function wrapResolve(depth: Int, dfdName: String, result: BuildResult): Expr {
		return
			if (result.resolved) {
				result.asyncExpr;
			}
			else {
				this.buildAsyncCall(result.asyncExpr, this.buildResolveClosure(depth, dfdName));
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

				default:
					{ asyncExpr: null, syncBlocks: this.syncBlocks, resolved: false };
				}	
			}
			else {
				switch(this.asyncExpr) {
				case Some(SAsyncCall(expr)) | Some(SAsyncExpr(expr)):
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosure(depth, expr)
					);

				case Some(SAsyncBlock(ctx, p)):
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosure(depth, ctx.buildRootBlock(p))
					);

				default:
					result.asyncExpr = this.buildAsyncCall(
						result.asyncExpr,
						this.buildClosure(depth, macro return $i{dfdName}.resolve())
					);
					result.resolved = true;
				}

				result;
			}
		;
	}

	// private function buildBlockInternal(depth: Int, dfdName: String, child: AsyncBlockChain): Array<Expr> {
	// 	return if (child.next == null) {
	// 		switch(child.asyncStmt) {
	// 		case SAsyncCall(expr, opt):
	// 			[expr];

	// 		case SAsyncExpr(expr, opt):
	// 			this.resolved = true;

	// 			var arg = child.asyncExpr;
	// 			[macro return $i{dfdName}.resolve(${arg})];				

	// 		case SAsyncBlock(blocks):
	// 			this.resolved = true;
	// 			[]
	// 		default:
	// 			throw "unsupported !!"; 
	// 		}
	// 	}
	// 	else {
	// 		[this.buildAsyncCall(
	// 			child.buildBlockExprInternal(depth, dfdName, child.next),
	// 			child.buildClosure(depth)
	// 		)];
	// 	}
	// }

	public function buildAsyncCall(receiver: Expr, arg: Expr): Expr {
        return {
            pos: receiver.pos,
            expr: ECall(
                { expr: EField(receiver, "then"), pos: Context.currentPos() }, 
                [arg]
            )
        };
	}

	private function extractClosureArgName(depth: Int): String {
		return 
			switch(this.asyncOption) {
			case OptVar(name): name;
			default: '_tmp${depth}';
			}
		;
	}

	private function buildClosure(depth, caller) {
        return buildClosureInternal(
        	extractClosureArgName(depth),
            {
                pos: Context.currentPos(),
                expr: EBlock(this.syncBlocks.concat(caller != null ? [ macro return $caller ] : []))
            }
        );		
	}

	private function buildResolveClosure(depth: Int, dfdName: String) {
		var argName = extractClosureArgName(depth);

        return buildClosureInternal(
        	argName,
            {
                pos: Context.currentPos(),
                expr: EBlock(this.syncBlocks.concat([ macro return $i{dfdName}.resolve($i{argName}) ]))
            }        
        );
	}

    private function buildClosureInternal(argName: String, blocksExpr: Expr): Expr {
        var args = [{ 
            name: argName, 
            type: TPath({ name: "Dynamic", pack: [], params: [] }), 
            opt: false, value: null 
        }];

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