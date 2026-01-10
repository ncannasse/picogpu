
#if (js && !hxnodejs)
import js.lib.Uint8Array;
@:native("fflate")
extern class FFlate {
  static function zlibSync(data:Uint8Array, ?opts:Dynamic):Uint8Array;
}
class FFlateInit {
	static function run( bytes : haxe.io.Bytes, ?opts ) {
		var level = opts.level ?? 9;
		var ret = FFlate.zlibSync(new js.lib.Uint8Array(bytes.getData()),{raw:false,level:level});
		var out = haxe.io.Bytes.ofData(ret.buffer);
		return out;
	}
	static function __init__() {
		var c = haxe.zip.Compress;
		(c:Dynamic).run = run;
	}
}
#end

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
		memory = memlines == "" ? [] : [for( l in memlines.split("\n") ) { var m = new PicoMem(); m.decode(StringTools.trim(l)); m; }];
		while( memory.length < 16 ) memory.push(new PicoMem());
	}

	public function getText() {
		cleanup();
		var mem = memory.copy();
		while( mem.length > 0 && mem[mem.length-1].data == Unknown ) mem.pop();
		return [
			"PICO-GPU.1",
			shaders.join("\n----\n"),
			code,
			[for( m in mem ) m.encode()].join("\n"),
		].join("\n#----\n");
	}

	static function compressCode( src : String ) {
		return haxe.zip.Compress.run(haxe.io.Bytes.ofString(src),9);
	}

	static function uncompressCode( data : haxe.io.Bytes ) {
		var buf = haxe.zip.Uncompress.run(data);
		return buf.getString(0,buf.length);
	}

	function cleanup() {
		while( shaders.length > 0 && (shaders[shaders.length-1] == null || StringTools.trim(shaders[shaders.length-1]) == "") ) shaders.pop();
	}

	public function getBytes(codeOnly=false) {
		cleanup();
		var b = new haxe.io.BytesBuffer();
		function addBytes( data : haxe.io.Bytes ) {
			if( data.length >= 65536 ) throw "assert";
			b.addByte(data.length & 0xFF);
			b.addByte(data.length >> 8);
			b.addBytes(data,0,data.length);
		}
		b.addString("PIG0");
		addBytes(compressCode(code));
		b.addByte(shaders.length);
		for( s in shaders )
			addBytes(compressCode(s));
		if( !codeOnly ) {
			for( i in 0...16 )
				memory[i].encodeBytes(b);
		}
		b.addByte(0xFE);
		return b.getBytes();
	}

	public function loadBytes( b : haxe.io.Bytes ) {
		var b = new haxe.io.BytesInput(b);
		if( b.readString(4) != "PIG0" )
			throw "This data is not a PICO-GPU file";
		function getBytes() {
			var len = b.readUInt16();
			return b.read(len);
		}
		code = uncompressCode(getBytes());
		shaders = [for( i in 0...b.readByte() ) uncompressCode(getBytes())];
		if( shaders.length > 16 ) throw "assert";
		memory = [for( i in 0...16 ) { var m = new PicoMem(); m.decodeBytes(b); m; }];
		if( b.readByte() != 0xFE ) throw "Invalid or corrupted file";
	}

	public function getCodeSize() {
		return getBytes(true).length;
	}

	public function getMemSize() {
		var tot = 0;
		for( m in memory )
			if( m != null )
				tot += m.getMemSize();
		return tot;
	}

	public function getTotalSize() {
		return getBytes().length;
	}

}