package jqd.builder;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;

import jqd.builder.Statement;

class AsyncBlockChain {
	private var next: AsyncBlockChain;
	private var syncBlocks: Array<Expr>;
	private var asyncExpr: Expr;
	private var asyncOption: AsyncOption;
	private var resolved: Bool;


	public function new(opt: AsyncOption, ?next: AsyncBlockChain) {
		this.resolved = false;
		this.next = next;
		this.asyncOption = opt;
		this.syncBlocks = new Array<Expr>();
	}

	public function pushSyncExpr(expr: Expr): Void {
		this.syncBlocks.push(expr);
	}

	public function newChain(expr: Expr, opt: AsyncOption) {
		this.asyncExpr = expr;

		return new AsyncBlockChain(opt, this);
	}

	public function buildBlockExpr(depth: Int): Array<Expr> {
		var dfdName = '_d${depth}';
		var inst = DeferredFactory.newInstExpr();

		// When pass follow expression Array.cocat directly, this.resolved has always false, why?
		var expr = if (this.next == null) { 
			[];
		}
		else {
			[ this.wrapResolve(depth, dfdName, this.buildBlockExprInternal(depth, dfdName, this.next)) ];
		}

		return new Array<Expr>()
			.concat([ macro var $dfdName = $inst ])
			.concat(this.getSyncBlocks())
			.concat(expr)
			.concat(this.resolved ? [] : [ macro return $i{dfdName} ])
		;
	}

	private function getSyncBlocks(): Array<Expr> {
		return (this.next == null) ? this.syncBlocks : this.next.getSyncBlocks();
	}

	private function wrapResolve(depth: Int, dfdName: String, expr: Expr): Expr {
		return
			if (this.resolved) {
				expr;
			}
			else {
				this.buildAsyncCall(expr, this.buildResolveClosure(depth, dfdName));
			}
		;
	}

	private function buildBlockExprInternal(depth: Int, dfdName: String, child: AsyncBlockChain): Expr {
		return if (child.next == null) {
			switch (child.asyncExpr.expr) {
			case EConst(_) | EBinop(_, _, _) | EField(_, _) | EArrayDecl(_) | ENew(_, _) | EUnop(_, _):
				this.resolved = true;

				var arg = child.asyncExpr;
				macro return $i{dfdName}.resolve(${arg});

			case ECall(_, _):
				child.asyncExpr;

			default:
				trace(child.asyncExpr);
				throw "unsupported !!"; 
			}
		}
		else {
			this.buildAsyncCall(
				child.buildBlockExprInternal(depth, dfdName, child.next),
				child.buildClosure(depth)
			);
		}
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

	private function extractClosureArgName(depth: Int): String {
		return 
			switch(this.asyncOption) {
			case OptVar(name): name;
			default: '_tmp${depth}';
			}
		;
	}

	private function buildClosure(depth) {
		var caller = this.asyncExpr;

        return buildClosureInternal(
        	extractClosureArgName(depth),
            {
                pos: Context.currentPos(),
                expr: EBlock(this.syncBlocks.concat([ macro return $caller ]))
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