package jqd.util;

using Lambda;
using haxe.EnumTools;

abstract ImmutableEnumFlags<T: EnumValue>(Int) {
	private inline function new(i = 0) {
		this = i;
	}

	public inline function has( v : T ) : Bool {
		return this & (1 << v.getIndex()) != 0;
	}

	public inline function any(values: Array<T>): Bool {
		var self = new ImmutableEnumFlags<T>(this);

		return values.exists(function(v: T) return self.has(v));
	}

	public inline function set( v : T): ImmutableEnumFlags<T> {
		return setInternal(v);
	}

	private inline function setInternal(v : EnumValue): ImmutableEnumFlags<T> {
		return new ImmutableEnumFlags<T>(
			this | (1 << v.getIndex())
		);		
	}

	public inline function unset(v : T) : ImmutableEnumFlags<T> {
		return new ImmutableEnumFlags<T>(
			this & (0xFFFFFFF - (1 << v.getIndex()))
		);
	}

	public inline function include(values: Array<T>): ImmutableEnumFlags<T> {
		return values.fold(
			function(val, result: ImmutableEnumFlags<T>): ImmutableEnumFlags<T> {
				return result.set(val);
			},
			new ImmutableEnumFlags<T>(this)
		);
	}

	public inline function exclude(values: Array<T>): ImmutableEnumFlags<T> {
		return values.fold(
			function(val, result: ImmutableEnumFlags<T>): ImmutableEnumFlags<T> {
				return result.unset(val);
			},
			new ImmutableEnumFlags<T>(this)
		);
	}

	public inline function or(rhs: ImmutableEnumFlags<T>): ImmutableEnumFlags<T> {
		return new ImmutableEnumFlags<T>(
			this | rhs
		);
	}

	@:from public inline static function of<T: EnumValue>(values: Array<EnumValue>) : ImmutableEnumFlags<T> {
		return values.fold(
			function(val, result: ImmutableEnumFlags<T>): ImmutableEnumFlags<T> {
				return result.setInternal(val);
			},
			new ImmutableEnumFlags<T>()
		);
	}	

	@:to public inline function toInt() : Int {
		return this;
	}
}
