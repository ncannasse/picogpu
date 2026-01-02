enum PicoMemData {
	Unknown;
	Ints( a : Array<Int> );
	Floats( a : Array<Single> );
	Texture( file : String, pixels : hxd.Pixels );
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
			data = Texture(file,res.getPixels());
		case 'U'.code:
			data = Unknown;
		default:
			throw "assert";
		}
	}

	public function encode() {
		return switch( data ) {
		case Unknown: "U";
		case Ints(a): "I:"+a;
		case Floats(a): "F:"+a;
		case Texture(file, pixels): "T:["+file+"]";
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
			data = Texture(null, null);
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
		case Texture(_,pix): pix.bytes;
		}
	}

	public function encodeBytes( out : haxe.io.BytesBuffer ) {
		out.addByte(data.getIndex());
		switch( data ) {
		case Unknown:
		case Ints(a):
			out.addInt32(a.length);
			for( v in a )
				out.addInt32(v);
		case Floats(a):
			out.addInt32(a.length);
			for( v in a )
				out.addFloat(v);
		case Texture(file, pixels):
			out.addByte(haxe.io.Bytes.ofString(file).length);
			out.addString(file);
			out.addInt32(pixels.width);
			out.addInt32(pixels.height);
			out.addByte(pixels.format.getIndex());
			out.addBytes(pixels.bytes,0,pixels.bytes.length);
		}
	}

	public function decodeBytes( input : haxe.io.Input ) {
		switch( input.readByte() ) {
		case 0:
			data = Unknown;
		case 1:
			data = Ints([for( i in 0...input.readInt32() ) input.readInt32()]);
		case 2:
			data = Floats([for( i in 0...input.readInt32() ) input.readFloat()]);
		case 3:
			var file = input.readString(input.readByte());
			var w = input.readInt32();
			var h = input.readInt32();
			var format = hxd.PixelFormat.createByIndex(input.readByte());
			var pixels = new hxd.Pixels(w,h,null,format);
			pixels.bytes = input.read(pixels.dataSize);
			data = Texture(file,pixels);
		default:
			throw "assert";
		}
	}

	public function toCodeString( stride : Int ) {
		function split( arr : Array<Dynamic>, n : Int ) {
			var v0 = arr[0];
			if( arr.length > 4 ) {
				var same = true;
				for( v in arr )
					if( v != v0 ) {
						same = false;
						break;
					}
				if( same )
					return "["+v0+"]["+arr.length+"]";
			}
			var b = new StringBuf();
			b.addChar('['.code);
			for( i => v in arr ) {
				var v : Float = v;
				if( i%n == 0 ) b.addChar('\n'.code);
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
			split(a,stride);
		case Floats(a):
			split(a,stride);
		case Texture(file, pixels):
			file+"("+pixels.width+"x"+pixels.height+" "+pixels.format+")";
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
		case [Ints(_), EArray({ e : EArrayDecl([{ e : EConst(CInt(v)) }])},{ e : EConst(CInt(len)) })]:
			data = Ints([for( i in 0...len ) v]);
		case [Floats(_), EArrayDecl(el)]:
			data = Floats([for( e in el ) switch( e.e ) { case EConst(CInt(v)): v; case EConst(CFloat(f)): f; default: invalid(e); }]);
		case [Floats(_), EArray({ e : EArrayDecl([{ e : EConst(CFloat(v)) }])},{ e : EConst(CInt(len)) })]:
			data = Floats([for( i in 0...len ) v]);
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
		case Texture(_, pixels):
			pixels?.dataSize;
		}
	}

}