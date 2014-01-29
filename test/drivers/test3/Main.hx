package drivers.test3;

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
		var x = @:yield callAsync(5);
		@:yield callAsync2([55, 66]);
		var y = @:yield callAsync(7);
		@:yield callAsync3(x,y);
	}

	@:async
	private function callAsync(n: Int) {
		return @:yield (n * 10);
	}

	@:async
	private function callAsync2(n: Array<Int>) {
		return @:yield [n, n];
	}

	@:async
	private function callAsync3(x: Int, y: Int) {
		return @:yield (x + y);
	}
}
