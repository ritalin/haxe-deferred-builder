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
		return @:yield try {
			@:yield run2();
		}
		// catch (ex: String) {
		// 	return @:yield ex;
		// }
		catch (errCode: Int) {
			return @:yield '${errCode}';
		}
		catch (_: Dynamic) {
			return @:yield "Unknown Error";
		}
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
