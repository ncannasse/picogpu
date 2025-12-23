
class PicoData {
	public var shaders : Array<String> = [];
	public var code : String;
	public var memory : Array<PicoMem> = [];
	public function new() {
		var defaults = hxd.Res.Defaults.entry.getText().split("----");
		inline function get() return StringTools.trim(defaults.shift());
		var version = get();
		if( version != "PICO-GPU.1" )
			throw "Invalid header";
		shaders = [for( v in get().split("--") ) StringTools.trim(v)];
		code = get();
		var memlines = get();
		memory = [for( l in memlines.split("\n") ) { var m = new PicoMem(); m.decode(StringTools.trim(l)); m; }];
	}

}