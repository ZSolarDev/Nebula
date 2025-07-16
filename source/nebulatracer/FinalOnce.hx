package nebulatracer;

import lime.utils.Log;

abstract FinalOnce<T>(FinalOnceImpl<T>)
{
	@:to inline function toValue():T
		return this.value;

	@:from static inline function fromValue<T>(val:T):FinalOnce<T>
	{
		var data = new FinalOnceImpl<T>();
		data.set(val);
		return new FinalOnce<T>(data);
	}

	public inline function new(d:FinalOnceImpl<T>)
	{
		this = d;
	}

	public inline function isSet():Bool
		return this._isSet;

	private inline function get():T
		return this.value;
}

private class FinalOnceImpl<T>
{
	public var value(get, never):T;
	public var _isSet:Bool = false;

	private var _value:T = null;

	public function new() {}

	public function set(v:T):Void
	{
		if (_isSet)
			Log.warn('A FinalOnce abstract was already set');
		_value = v;
		_isSet = true;
	}

	inline function get_value():T
		return _value;
}
