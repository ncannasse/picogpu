
class PicoLinkedShader {
	public var rt : hxsl.RuntimeShader;
	public var list : hxsl.ShaderList;
	public var format : hxd.BufferFormat;
	public var shaders : Array<PicoShader>;
	public function new(rt,list,shaders) {
		this.rt = rt;
		this.list = list;
		this.shaders = shaders;
		this.format = rt.getInputFormat();
	}
}

@:access(PicoBuffer)
class PicoApi {

	var gpu : PicoGpu;
	var currentShaders : Array<PicoShader>;
	var shaderCombi : Map<String,PicoLinkedShader> = new Map();
	var currentShader : PicoLinkedShader;
	var currentMaterial : h3d.mat.Pass;
	var currentOutput : h3d.pass.OutputShader;
	var globals = new hxsl.Globals();
	var buffers = new h3d.shader.Buffers();
	var camera = new h3d.Camera();
	var needFlush = true;

	var data : PicoData;
	var memory : Array<PicoBuffer>;
	var shaders : Array<PicoShader>;

	public function new(gpu:PicoGpu) {
		this.gpu = gpu;
		currentOutput = new h3d.pass.OutputShader();
		currentOutput.setOutput([Value("outputColor")],"outputPosition");
		currentMaterial = new h3d.mat.Pass("default");
	}

	function loadData( data : PicoData ) {
		this.data = data;
		memory = [for( i in data.memory ) new PicoBuffer(i)];
		shaders = [for( i => code in data.shaders ) { var s = new PicoShader(i); try s.setCode(code) catch( e : Dynamic ) {}; s; }];
	}

	function updateShader( s : PicoShader ) {
		shaders[s.index] = s;
		for( c in shaderCombi ) {
			var repl = false;
			for( s2 in c.shaders )
				if( s2.index == s.index ) {
					repl = true;
					break;
				}
			if( repl )
				shaderCombi.remove([for( s in c.shaders ) s.index].join("#"));
		}
	}

	function updateBuffer( index : Int ) {
		var prev = memory[index];
		prev?.dispose();
		memory[index] = new PicoBuffer(data.memory[index]);
	}

	public function loadBuffer( index : Int ) : PicoBuffer {
		return memory[index];
	}

	public function loadTexture( index : Int, ?width : Int ) {
		return memory[index]?.toTexture(width);
	}

	public function setShader( index : Int, ?fragment ) {
		var arr = [index];
		if( fragment != null ) arr.push(fragment);
		return setShaders(arr);
	}

	public function setShaders( arr : Array<Int> ) {
		var shaders = [];
		for( index in arr ) {
			var s = this.shaders[index];
			if( s == null ) {
				log("Invalid shader index #"+index);
				return false;
			}
			if( s.shader == null ) {
				log("Shader #"+index+" is invalid");
				return false;
			}
			shaders.push(s);
		}
		var key = arr.join("#");
		var sh = shaderCombi.get(key);
		if( sh == null ) {
			var sl = null;
			for( i in 0...arr.length )
				sl = new hxsl.ShaderList(shaders[arr.length - 1 - i].shader,sl);
			var rt = currentOutput.compileShaders(globals, sl);
			sh = new PicoLinkedShader(rt,sl,shaders);
			shaderCombi.set(key, sh);
		}
		if( currentShader != sh ) {
			currentShader = sh;
			needFlush = true;
		}
		return true;
	}

	public function setVariable( name : String, value : Dynamic ) {
		if( currentShader != null ) {
			for( s in currentShader.shaders )
				s.shader.setVariable(name, value);
		}
	}

	function flush() {
		if( currentShader == null ) return;
		if( !needFlush ) return;
		needFlush = false;
		camera.update();
		setVariable("cameraViewProj", camera.m);
		buffers.grow(currentShader.rt);
		@:privateAccess gpu.s3d.ctx.fillGlobals(buffers,currentShader.rt);
		@:privateAccess gpu.s3d.ctx.fillParams(buffers,currentShader.rt,currentShader.list);
		gpu.engine.selectMaterial(currentMaterial);
		gpu.engine.selectShader(currentShader.rt);
		gpu.engine.uploadShaderBuffers(buffers, Globals);
		gpu.engine.uploadShaderBuffers(buffers, Params);
		gpu.engine.uploadShaderBuffers(buffers, Textures);
		gpu.engine.uploadShaderBuffers(buffers, Buffers);
	}

	public function draw( buffer : PicoBuffer, ?index : PicoBuffer, ?startTri = 0, ?drawTri = -1 ) {
		if( currentShader == null ) return;
		if( buffer == null ) {
			log("Null buffer");
			return;
		}
		flush();
		gpu.engine.renderIndexed(buffer.alloc(currentShader.format), index.allocIndexes(), startTri, drawTri);
	}

	public function log( v : Dynamic ) {
		gpu.logOnce(v);
	}

	function beginFrame() {
		needFlush = true;
	}

}

class PicoBuffer {
	var mem : PicoMem;
	var buffer : h3d.Buffer;
	var texture : h3d.mat.Texture;
	var bytes : haxe.io.Bytes;

	public function new(mem) {
		this.mem = mem;
	}

	function alloc(format:hxd.BufferFormat) {
		if( buffer == null || buffer.format != format ) {
			buffer?.dispose();
			var bytes = getBytes();
			buffer = new h3d.Buffer(Std.int(bytes.length/format.strideBytes),format);
			buffer.uploadBytes(bytes,0,buffer.vertices);
		}
		return buffer;
	}

	function dispose() {
		buffer?.dispose();
		texture?.dispose();
		bytes = null;
	}

	function allocIndexes() {
		return h3d.Indexes.ofBuffer(alloc(hxd.BufferFormat.INDEX32));
	}

	function getBytes() {
		if( bytes == null )
			bytes = mem.getBytes();
		return bytes;
	}

	public function toTexture( ?width : Int ) : PicoTexture {
		if( width == null )
			switch( mem.data ) {
			case Texture(_,_,pix): width = pix.width;
			default:
				width = Std.int(Math.sqrt(getBytes().length>>4));
			}
		if( texture == null || texture.width != width ) {
			var bytes = getBytes();
			texture?.dispose();
			texture = new h3d.mat.Texture(width, Std.int((bytes.length>>2)/width));
			texture.uploadPixels(new hxd.Pixels(width,texture.height,bytes,BGRA));
		}
		return texture;
	}
}

class PicoShader {
	public var index : Int;
	public var shader : hxsl.DynamicShader;
	public var inits : Map<String,Dynamic>;

	public function new(index) {
		this.index = index;
	}

	public function setCode( code : String ) {
		var parser = new hscript.Parser();
		parser.allowMetadata = true;
		parser.allowTypes = true;
		var name = "shader#"+index;
		var expr = parser.parseString(code,name);
		var mexpr = new hscript.Macro(null).convert(expr);
		var hparser = new hxsl.MacroParser();
		var hexpr = hparser.parseExpr(mexpr);
		var shared = new hxsl.SharedShader("");
		var checker = new hxsl.Checker();
		shared.data = checker.check(name, hexpr);
		@:privateAccess shared.initialize();
		shader = new hxsl.DynamicShader(shared);
		for( v in checker.inits )
			shader.setVariable(v.v.name, hxsl.Ast.Tools.evalConst(v.e));
	}

}

abstract PicoTexture(h3d.mat.Texture) from h3d.mat.Texture {
}