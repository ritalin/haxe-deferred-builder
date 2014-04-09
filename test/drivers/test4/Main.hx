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
		var results = 
			@:yield for (x in 1...10) {
				@:yield callAsync(x);
			}
		;

		@:yield return results;
	}

	@:async
	public function run2() {
		var n = @:yield callAsync(50);

		var results = 
			@:yield for (x in 1...10) {
				@:yield callAsync(x + n);
			}
		;

		@:yield return results;
	}

	@:async
	public function run3() {
		var n = 10;
		var results = 
			@:yield while (--n >= 0) {
				@:yield callAsync(n);
			}
		;

		@:yield return results;
	}

	@:async
	public function run4() {
		var n = 10;
		var results = 
			@:yield while (n >= 0) {
				@:yield callAsync(n);
				--n;
			}
		;

		@:yield return results;
	}

	@:async
	public function run5() {
		var n = 10;
		var results = 
			@:yield do {
				@:yield callAsync(n);
				--n;
			}
			while (n >= 0)
		;

		@:yield return results;
	}

	@:async
	private function callAsync(n: Int) {
		@:yield return (n * 10);
	}
}
