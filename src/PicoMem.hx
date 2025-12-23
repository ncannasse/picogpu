enum PicoMemData {
	Unknown;
	Ints( a : Array<Int> );
	Floats( a : Array<Single> );
	Texture( file : String, rawBytes : haxe.io.Bytes, pixels : hxd.Pixels );
}

class PicoMem {

	public var data : PicoMemData;

	public function new() {
		data = Unknown;
	}

	public function decode( str : String ) {
		var arr = str.substr(3, str.length - 4).split(",");
		return switch( str.charCodeAt(0) ) {
		case 'I'.code:
			data = Ints([for( v in arr ) Std.parseInt(v)]);
		case 'F'.code:
			data = Floats([for( v in arr ) Std.parseFloat(v)]);
		case 'T'.code:
			var file = arr[0];
			var res = hxd.Res.load(file).toImage();
			data = Texture(file,res.entry.getBytes(), res.getPixels());
		default:
			throw "assert";
		}
	}

	public function setMode( m : Int ) {
		switch( m ) {
		case 0:
			data = Unknown;
		case 1:
			data = Ints([]);
		case 2:
			data = Floats([]);
		case 3:
			data = Texture(null, null, null);
		default:
			throw "assert";
		}
	}

	public function canEditCode() {
		return switch( data ) {
		case Unknown, Texture(_): false;
		default: true;
		}
	}

	public function getBytes() {
		return switch( data ) {
		case Unknown: null;
		case Ints(arr): @:privateAccess new haxe.io.Bytes(hl.Bytes.getArray(arr), arr.length << 2);
		case Floats(arr): @:privateAccess new haxe.io.Bytes(hl.Bytes.getArray(arr), arr.length << 2);
		case Texture(_,_,pix): pix.bytes;
		}
	}

	public function toCodeString() {
		function split( arr : Array<Dynamic>, n : Int ) {
			var b = new StringBuf();
			b.addChar('['.code);
			for( i => v in arr ) {
				var v : Float = v;
				if( i%4 == 0 ) b.addChar('\n'.code);
				b.add(v);
				b.add(', ');
			}
			b.addChar('\n'.code);
			b.addChar(']'.code);
			return b.toString();
		}
		return switch( data ) {
		case Unknown:
			null;
		case Ints(a):
			split(a,4);
		case Floats(a):
			split(a,4);
		case Texture(file, _):
			file;
		}
	}

	public function parseCode( code : String ) {
		var p = new hscript.Parser();
		var expr = p.parseString(code,"");
		function invalid(e:hscript.Expr) : Dynamic {
			throw new hscript.Expr.Error(ECustom("Invalid Format"),e.pmin,e.pmax,"",e.line);
		}
		switch( [data,expr.e] ) {
		case [Ints(_), EArrayDecl(el)]:
			data = Ints([for( e in el ) switch( e.e ) { case EConst(CInt(v)): v; default: invalid(e); }]);
		case [Floats(_), EArrayDecl(el)]:
			data = Floats([for( e in el ) switch( e.e ) { case EConst(CInt(v)): v; case EConst(CFloat(f)): f; default: invalid(e); }]);
		default:
			invalid(expr);
		}
	}

	public function getMemSize() {
		return switch( data ) {
		case Unknown:
			0;
		case Ints(a):
			a.length * 4;
		case Floats(a):
			a.length * 4;
		case Texture(_, _, pixels):
			pixels?.dataSize;
		}
	}

}