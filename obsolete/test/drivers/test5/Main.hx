package drivers.test5;

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
		@:yield throw "None.";
	}

	@:async
	public function run2(): Promise {
		var n1 = @:yield callAsync(1);
		
		@:yield throw "Terminated.";
	}

	@:async
	public function run3(): Promise {
		@:yield return try {
			@:yield run2();
		}
		// catch (ex: String) {
		// 	return @:yield ex;
		// }
		catch (errCode: Int) {
			@:yield return '${errCode}';
		}
		catch (_: Dynamic) {
			@:yield return "Unknown Error";
		}
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
