package drivers.test4;

import jQuery.Promise;
import jQuery.Deferred;

class Main {
	static function main() {
		new Target().run();
	}
}

@:build(jqd.builder.DeferredBuilder.build())
private class Target {
	public function new() {}

	@:async
	public function run() {
		return 
			@:yield for (x in 1...10) {
				@:yield callAsync(x);
			}
		;
	}

	@:async
	private function callAsync(n: Int) {
		return @:yield (n * 10);
	}
}

private class Target2 {
	public function new() {}

	public function run() {
		var _d = new Deferred();
		var _da = new Array<Promise>();
		for (x in 1...10) {
			var _d2: Deferred = new Deferred();
			callAsync(x).then(function(_tmp2) {
				return _d2.resolve(_tmp2);
			});

			_da.push(_d2);
		}
		(untyped JQuery).when.apply(_da, _da).then(function() {
			var _d2 = new Deferred();

			return _d2.resolve(untyped [].slice.apply(__js__("arguments")));
		})
		.then(function(_return) {
			return _d.resolve(_return);
		});

		return _d;
	}

	private function callAsync(n: Int) {
		return new Deferred().resolve(n * 10);
	}
}

