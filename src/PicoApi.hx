
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
@:access(PicoTexture)
class PicoApi {

	public static final FPS = 60;
	public static final WIDTH = 640;
	public static final HEIGHT = 480;
	public static final MAX_SIZE = WIDTH * HEIGHT;

	var gpu : PicoGpu;
	var shaderCombi : Map<String,PicoLinkedShader>;
	var currentShader : PicoLinkedShader;
	var currentMaterial : h3d.mat.Pass;
	var currentOutput : h3d.pass.OutputShader;
	var renderCtx : h3d.impl.RenderContext;
	var buffers : h3d.shader.Buffers;
	var outTexture : h3d.mat.Texture;
	var needFlush = true;

	var data : PicoData;
	var memory : Array<PicoBuffer>;
	var shaders : Array<PicoShader>;

	var startTime : Float;
	var frameOffset = -1;

	public function new(gpu:PicoGpu) {
		this.gpu = gpu;
		currentOutput = new h3d.pass.OutputShader();
		currentOutput.setOutput([Value("outputColor")],"outputPosition");
		reset();
		init();
	}

	function reset() {
		buffers = new h3d.shader.Buffers();
		shaderCombi = new Map();
		renderCtx = @:privateAccess new h3d.impl.RenderContext();
		currentMaterial = new h3d.mat.Pass("default");
		currentShader = null;
		needFlush = true;
		frameOffset = -1;
		if( memory != null ) {
			for( m in memory )
				m.dispose();
		}
		if( data != null )
			loadData(data);
	}

	function init() {
		outTexture = new h3d.mat.Texture(WIDTH,HEIGHT,[Target]);
		outTexture.depthBuffer = new h3d.mat.Texture(WIDTH,HEIGHT,[Target],h3d.mat.Data.TextureFormat.Depth24Stencil8);
		setCamera(new h3d.Camera().mcam);
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

	// ---- BUFFERS & TEXTURES ----

	/**
		Load the memory buffer at the given Memory index.
		You can have up to 16 different memory buffers.
		The total memory (including code data) cannot exceed 64KB
	**/
	public function loadBuffer( index : Int ) : PicoBuffer {
		return memory[index];
	}

	/**
		Same as loadBuffer(index).getTexture()
	**/
	public function loadTexture( index : Int ) {
		return memory[index]?.getTexture();
	}

	// ---- SHADERS -----

	/**
		Set the current shader, or a combination of two shaders.
	**/
	public function setShader( index : Int, ?fragment ) {
		var arr = [index];
		if( fragment != null ) arr.push(fragment);
		return setShaders(arr);
	}

	/**
		Set the current shader, as a combination of multiple shaders.
	**/
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
			for( s in shaders )
				sl = new hxsl.ShaderList(s.shader,sl);
			var rt = currentOutput.compileShaders(renderCtx.globals, sl);
			sh = new PicoLinkedShader(rt,sl,shaders);
			shaderCombi.set(key, sh);
		}
		if( currentShader != sh ) {
			currentShader = sh;
			needFlush = true;
		}
		return true;
	}

	/**
		Set the global value. It will be accessible in shader variables with the @global qualifier.
	**/
	public function setGlobal( name : String, value : Dynamic ) {
		renderCtx.globals.set(name, value);
	}

	/**
		Set the parameter for all current shaders. It will be accessible in shader variables with the @param qualifier.
	**/
	public function setParam( name : String, value : Dynamic ) {
		if( currentShader != null ) {
			for( s in currentShader.shaders )
				s.shader.setVariable(name, value);
		}
	}

	/**
		Set the camera rotation matrix, given the specified vertical FoV.
		You can also directly set the cameraViewProj global.
	**/
	public function setCamera( m : h3d.Matrix, fovY = 25.0 ) {
		var cam = new h3d.Camera();
		var out = new h3d.Matrix();
		cam.screenRatio = @:privateAccess (outTexture.width / outTexture.height);
		cam.fovY = fovY;
		@:privateAccess cam.makeFrustumMatrix(out);
		out.multiply(m, out);
		setGlobal("cameraViewProj", out);
	}

	// --- MATHS ----

	/**
		Create a 4x4 Matrix
	**/
	public function mat4(?arr:Array<Float>) {
		return arr == null ? h3d.Matrix.I() : h3d.Matrix.L(arr);
	}

	/**
		Create a 4-components Vector
	**/
	public function vec4( ?x = 0., ?y, ?z, ?w ) {
		if( y == null && z == null && w == null )
			return new h3d.Vector4(x,x,x,x);
		return new h3d.Vector4(x,y,z,w);
	}

	/**
		Create a 3-components Vector
	**/
	public function vec3( ?x = 0., ?y, ?z ) {
		if( y == null && z == null )
			return new h3d.Vector(x,x,x);
		return new h3d.Vector(x,y,z);
	}

	/**
		Create a Quaternion
	**/
	public function quat( x = 0., y = 0., z = 0., w = 1. ) {
		return new h3d.Quat(x,y,z,w);
	}

	// --- MATERIAL ----

	/**
		Set the culling mode (0 = disable, 1 : back face, -1 : front face).
	**/
	public function cull( v : Int ) {
		currentMaterial.culling = v == 0 ? None : v > 0 ? Back : Front;
		needFlush = true;
	}

	/**
		Set the blending mode. They can be accessessed using the `Blend` global
	**/
	public function blend( src, dst ) {
		currentMaterial.blend(src, dst);
		needFlush = true;
	}

	/**
		Set the depth compare mode (using the `Compare` global) and tell if the depth should be written.
	**/
	public function depth( comp, write = true ) {
		currentMaterial.depthTest = comp;
		currentMaterial.depthWrite = write;
		needFlush = true;
	}

	/**
		Set the color mask bits for all write operations
	**/
	public function colorMask( bits = 15 ) {
		currentMaterial.colorMask = bits;
	}

	// ---- DRAW -----

	function flush() {
		if( currentShader == null ) return;
		if( !needFlush ) return;
		needFlush = false;
		buffers.grow(currentShader.rt);
		renderCtx.fillGlobals(buffers,currentShader.rt);
		renderCtx.fillParams(buffers,currentShader.rt,currentShader.list);
		gpu.engine.selectMaterial(currentMaterial);
		gpu.engine.selectShader(currentShader.rt);
		gpu.engine.uploadShaderBuffers(buffers, Globals);
		gpu.engine.uploadShaderBuffers(buffers, Params);
		gpu.engine.uploadShaderBuffers(buffers, Textures);
		gpu.engine.uploadShaderBuffers(buffers, Buffers);
	}

	/**
		Change the current render target. Call with null or 0 parameters to reset the default output.
	**/
	public function setTarget( ?t : PicoTexture ) {
		gpu.engine.driver.setRenderTarget(t.tex ?? outTexture);
	}

	/**
		Clear the current target color.
	**/
	public function clear( color ) {
		gpu.engine.driver.clear(color);
	}

	/**
		Draw using the vertex buffer using the current shader. Use either triangles or specified index buffer.
	**/
	public function draw( buffer : PicoBuffer, ?index : PicoBuffer, ?startTri = 0, ?drawTri = -1 ) {
		if( currentShader == null ) return;
		if( buffer == null ) {
			log("Null buffer");
			return;
		}
		flush();
		if( index == null )
			gpu.engine.renderTriBuffer(buffer.alloc(currentShader.format), startTri, drawTri);
		else
			gpu.engine.renderIndexed(buffer.alloc(currentShader.format), index.allocIndexes(), startTri, drawTri);
	}

	function hasFocus() {
		return gpu.sevents.getFocus() != null;
	}

	// --- CONTROLS ----

	/**
		Checks if the keyboard key is currently down. Key codes are accessible with the `Key` global variable.
	**/
	public function keyDown( code : Int ) {
		return !hasFocus() && hxd.Key.isDown(code);
	}

	/**
		Checks if the keyboard key was pressed this frame. Key codes are accessible with the `Key` global variable.
	**/
	public function keyPressed( code : Int ) {
		return !hasFocus() && hxd.Key.isPressed(code);
	}

	/**
		Checks if the keyboard key was released this frame. Key codes are accessible with the `Key` global variable.
	**/
	public function keyReleased( code : Int ) {
		return !hasFocus() && hxd.Key.isReleased(code);
	}

	/**
		Log a message in the console.
	**/
	public function log( v : Dynamic ) {
		gpu.logOnce(v);
	}

	function beginFrame() {
		if( frameOffset < 0 ) {
			startTime = haxe.Timer.stamp();
			frameOffset = hxd.Timer.frameCount;
		}
		var frames = hxd.Timer.frameCount - frameOffset;
		var time = startTime + frames / FPS;
		// loop until exact FPS
		while( haxe.Timer.stamp() < time ) {
		}
		needFlush = true;
		setGlobal("time", frames / FPS);
	}

}

class PicoBuffer {
	var mem : PicoMem;
	var buffer : h3d.Buffer;
	var texture : h3d.mat.Texture;
	var bytes : haxe.io.Bytes;

	/**
		The size of the buffer, in bytes
	**/
	public var length(get,never) : Int;

	public function new(mem) {
		this.mem = mem;
	}

	function get_length() return getBytes().length;

	public function getI32( index : Int ) {
		return getBytes().getInt32(index << 2);
	}

	public function getF32( index : Int ) {
		return getBytes().getFloat(index << 2);
	}

	public function setI32( index : Int, v : Int ) {
		getBytes().setInt32(index << 2, v);
		dispose();
	}

	public function setF32( index : Int, v : Single ) {
		getBytes().setFloat(index << 2, v);
		dispose();
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
		buffer = null;
		texture = null;
	}

	function allocIndexes() {
		return h3d.Indexes.ofBuffer(alloc(hxd.BufferFormat.INDEX32));
	}

	function getBytes() {
		if( bytes == null ) {
			// make a copy so we can modify it later
			var b = mem.getBytes();
			bytes = b.sub(0, b.length);
		}
		return bytes;
	}

	/*
		Convert the memory buffer into a texture to be used as shader variable
		or another operation. If the buffer is modified, the texture will be disposed.
	*/
	public function getTexture() : PicoTexture {
		if( texture != null )
			return texture;
		switch( mem.data ) {
		case Unknown:
			return null;
		case Texture(_,pix):
			texture = new h3d.mat.Texture(pix.width, pix.height, [Target], pix.format);
			texture.uploadPixels(new hxd.Pixels(pix.width,pix.height,getBytes(),pix.format));
		default:
			var size = getBytes().length>>2;
			var width = Std.int(Math.sqrt(size));
			var height = Std.int(size/width);
			texture = new h3d.mat.Texture(width, height, [Target]);
			texture.uploadPixels(new hxd.Pixels(width,height,bytes,BGRA));
		}
		texture.wrap = Repeat;
		texture.filter = Nearest;
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

@:forward(width,height,isDisposed)
abstract PicoTexture(h3d.mat.Texture) from h3d.mat.Texture {

	var tex(get,never) : h3d.mat.Texture;
	inline function get_tex() return this;

	public function filter( b : Bool ) {
		this.filter = b ? Linear : Nearest;
	}
	public function wrap( b : Bool ) {
		this.wrap = b ? Repeat : Clamp;
	}
}