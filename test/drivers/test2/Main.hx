package drivers.test2;

import jQuery.Deferred;
import jQuery.Promise;

class Main {
	static function main() {
		new Target().run();
	}
}

@:build(jqd.builder.DeferredBuilder.build())
private class Target {
	public function new() {}

	@:async
	public function run(): Promise {
		var x = 200;
		@:yield {			
			var x = 10;
			@:yield callAsync(1);
		}
		var y = x+10;
		@:yield callAsync2([1]);

		// var _d2 = new Deferred();
		// {
		// 	callAsync(1);
		// }
		// _d2.then(function(_tmp1) {

		// });

	}

	// run: function() {
	// 	var _d1 = new Deferred();
	//
	// ここから
	// 	var _d2 = new Deferred();
	// 	{
	// 		callAsync(1)
	// 			.then(function() {
	// 				return _d2.resolve();
	// 			})
	// 		;
	// 	}
	// ここまで同期ブロックとして処理させる
	//
	// _d2をダミーの非同期式としてチェインに押し込む
	// 	_d2.then(function() {
	// 		return callAsync2([1]);
	// 	})
	// 	.then(function() {
	// 		return _d1.resolve();
	// 	});
	//
	// 	return d;
	// },

	@:async
	private function callAsync(n: Int) {
		return @:yield (n * 10);
	}

	@:async
	private function callAsync2(n: Array<Int>) {
		return @:yield [n, n];
	}
}
