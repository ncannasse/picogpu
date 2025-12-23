
class PicoData {
	public var shaders : Array<String> = [];
	public var code : String;
	public var memory : Array<PicoMem> = [];

	public function new() {
	}

	public function loadText( text : String ) {
		var lines = text.split("#----");
		inline function get() return StringTools.trim(lines.shift());
		var version = get();
		if( version != "PICO-GPU.1" )
			throw "Invalid header";
		shaders = [for( v in get().split("----") ) StringTools.trim(v)];
		code = get();
		var memlines = get();
		memory = [for( l in memlines.split("\n") ) { var m = new PicoMem(); m.decode(StringTools.trim(l)); m; }];
	}

	public function getText() {
		return [
			"PICO-GPU.1",
			shaders.join("\n----\n"),
			code,
			[for( m in memory ) m.encode()].join("\n"),
		].join("\n#----\n");
	}

	public function getCodeSize() {
		var tot = code.length;
		for( s in shaders )
			tot += s.length;
		return tot;
	}

	public function getMemSize() {
		var tot = 0;
		for( m in memory )
			if( m != null )
				tot += m.getMemSize();
		return tot;
	}

	public function getTotalSize() {
		return getCodeSize() + getMemSize();
	}

}