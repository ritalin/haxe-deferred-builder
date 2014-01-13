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

		@:yield callAsync(n1);
	}

	@:async
	private function callAsync(n: Int) {
		return @:yield (n * 10);
	}
}
