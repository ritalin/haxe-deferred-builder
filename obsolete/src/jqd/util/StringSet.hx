package jqd.util;

import haxe.ds.StringMap;

class StringSet {
	private var map: StringMap<Bool>;

	public static function from(entries: Iterable<String>): StringSet {
		var results = new StringSet();

		for (k in entries) { results.add(k); }

		return results;
	}

	public function new() {
		this.map = new StringMap<Bool>();
	}

	public function add(entry: String) {
		this.map.set(entry, true);
	}

	public function concat(other: Iterable<String>): StringSet {
		var results = StringSet.from(this);
		for (k in other) { results.add(k); }

		return results;
	}

	public function exists(entry: String): Bool {
		return this.map.exists(entry);
	}

	public function iterator(): Iterator<String> {
		return this.map.keys();
	}
}