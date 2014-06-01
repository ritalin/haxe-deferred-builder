package jqd.builder;

import haxe.macro.Context;
import haxe.macro.Expr;

class DeferredBuilder {
	macro
	public static function build(): Array<Field> {
		return new DeferredAstVisitor(Context.getBuildFields()).process();
	}
}