package drivers.test6;

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
	private function callAsync(n: Int) {
		@:yield return (n * 10);
	}

	@:async
	private function callAsync2(n: Int) {
		@:yield return [n, n*2];
	}

	@:async
	public function run(): Promise {
		@:yield return callAsync(100);
	}

	@:async
	private function run2(m) {
		@:yield if (m == 0) {
			@:yield callAsync(30);
		}

		@:yield callAsync2(100);
	}

	// {
	// 	var _d1 = new Deferred();

	// 	var _d3 = new Deferred();
	// 	var _d3if = if (m == 0) {
	// 		var _d4 = new Deferred();

	// 		callAsync(30)
	// 		.then(function() {
	// 			return _d3.resolve();
	// 		});
	// 	}
	// 	else {
	// 		_d3.resolve();
	// 	}

	// 	_d3if.then(function() {
	// 		return callAsync2(100);
	// 	})
	// 	.then(function() {
	// 		return _d1.resolve();
	// 	});

	// 	return _d1;
	// }

	@:async
	private function run3(n: Int) {
		var m = n + 100;
		@:yield callAsync(m * 5);
		@:yield if (n % 2 == 0) {
			@:yield callAsync2(1);
		}

		@:yield return (n * 10);
	}
	@:async
	private function run4(n: Int) {
		var m = n + 100;
		@:yield if (n % 2 == 0) {
			@:yield return;
		}
		@:yield callAsync(m * 5);
	}

	// {
	// 	var _d1 = new Deferred();

	// 	var m = n + 100;

	// 	callAsync(m*5)
	// 	.then(function() {
	// 		var _d2 = new Deferred();

	// 		return if (n % 2 == 0) {
	// 			callAsync2(1)
	// 			.then(function() {
	// 				return _d2.resolve();
	// 			});
	// 		}
	// 		else {
	// 			_d2.resolve();
	// 		}
	// 	})
	// 	.then(function() {
	// 		return _d2.resolve(n * 10);
	// 	})
	// 	.then(function(_tmp1) {
	// 		return _d1.resolve(_tmp1);
	// 	})

	// 	return _d1;
	// }

	// @:async
	// private function callAsync2(n: Int) {
	// 	@:yield return if (n == 0) {
	// 		@:yield [n, n*2];
	// 	}
	// 	else if (n < 10) {
	// 		@:yield [n * 100, n + 100];
	// 	}
	// 	else {
	// 		@:yield callASync2(n / 2);
	// 	}
	// }

	// {
	// 	var _d1 = new Deferred();

	// 	var _d2 = 
	// 		if (n == 0) {
	// 			var _d3 = new Deferred();

	// 			_d3.resolve([n, n*2]);
	// 		}
	// 		else if (n < 10) {
	// 			var _d3 = new Deferred();

	// 			_d3.resolve([n * 100, n + 100]);
	// 		}
	// 		else {
	// 			var _d3 = new Deferred();

	// 			callASync2(n / 2)
	// 			.then(function() {
	// 				return _d3.resolve();
	// 			});
	// 		}
	// 	;

	// 	_d2.then(function(_tmp1) {
	// 		return _d1.resolve();
	// 	});

	// 	return _d1;
	// }
}
