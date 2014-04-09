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

		@:yield return callAsync2(n2);
	}

	@:async
	private function callAsync(n: Int) {
		@:yield return (n * 10);
	}

	@:async
	private function callAsync2(n: Int) {
		@:yield return [n, n*2];
	}
}
