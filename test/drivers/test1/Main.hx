package drivers.test1;

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
		var n1 = @:yield callAsync(1);
		var n2 = @:yield callAsync(n1);

		return @:yield callAsync2(n2);
	}

	@:async
	private function callAsync(n: Int) {
		return @:yield (n * 10);
	}

	@:async
	private function callAsync2(n: Int) {
		return @:yield [n, n*2];
	}
}
