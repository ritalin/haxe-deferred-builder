package jqd.builder;

import haxe.macro.Expr;
import haxe.macro.Context;

private typedef ClassDef = {
	public var packages: Array<String>;
	public var name: Null<String>;
}

class DeferredFactory {
	private static var dfdClass: ClassDef = { packages: ["jQuery"], name: "Deferred" };
	private static var promiseClass: ClassDef = { packages: ["jQuery"], name: "Promise" };

	public static function className(dfd: String, promise: String): Void {
		var parse = function(cl: String): ClassDef {
			var parts = cl.split(".");

			return { name: parts.pop(), packages: parts };
		}

		dfdClass = parse(dfd);
//		promiseClass = parse(promise);
	}

	public static function newInstExpr(): Expr {
		return {
			expr: ENew({ name: dfdClass.name, pack: dfdClass.packages, params: [] }, []), 
			pos: Context.currentPos()
		};
	}

	// public static function returnPromiseType(): ComplexType {
	// 	return TPath({ 
	// 		name: promiseClass.name, 
	// 		pack: promiseClass.packages, 
	// 		params: [] 
	// 	});
	// }
}