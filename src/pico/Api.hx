package pico;

import hxd.Key in K;

private class LinkedShader {
	public var rt : hxsl.RuntimeShader;
	public var list : hxsl.ShaderList;
	public var format : hxd.BufferFormat;
	public var instanceFormat : hxd.BufferFormat;
	public var shaders : Array<PicoShader>;
	public function new(rt,list,shaders) {
		this.rt = rt;
		this.list = list;
		this.shaders = shaders;
		this.format = rt.getInputFormat();
		this.instanceFormat = rt.getInputFormat(true);
		if( this.instanceFormat.stride == 0 ) this.instanceFormat = null;
	}
}

private class SoundShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var offset : Float;
		@param var highOffset : Float;
		@param var freq : Float;
		@param var bufferSize : Float;
		var sound : Float;
		var time : Float;
		var time2 : Float;
		var frequency : Float;
		function __init__fragment() {
			frequency = freq;
			time = (offset + calculatedUV.x) * (bufferSize / freq);
			time2 = highOffset * (bufferSize / freq);
			sound = 0;
		}
		function fragment() {
			pixelColor = vec4(sound,0,0,1);
		}
	};
}

@:access(pico.Buffer)
@:access(pico.Texture)
class Api {

	static final FPS = 60;
	static final WIDTH = 640;
	static final HEIGHT = 480;
	static final MAX_SIZE = WIDTH * HEIGHT;

	var gpu : PicoGpu;
	var shaderCombi : Map<String,LinkedShader>;
	var currentShader : LinkedShader;
	var currentMaterial : h3d.mat.Pass;
	var currentOutput : h3d.pass.OutputShader;
	var renderCtx : h3d.impl.RenderContext;
	var buffers : h3d.shader.Buffers;
	var outTexture : h3d.mat.Texture;
	var needFlush = true;

	var data : PicoData;
	var memory : Array<Buffer>;
	var shaders : Array<PicoShader>;
	var sound : hxd.snd.Driver;
	var channels : Array<{ c : PicoChannel, shader : PicoShader, output : h3d.mat.Texture }>;
	var soundRender : h3d.pass.ScreenFx<SoundShader>;

	var startTime : Float;
	var frameOffset = -1;
	var buttonDown : Bool;
	var button2Down : Bool;

	var displayTex : Texture;

	function new(gpu:PicoGpu) {
		this.gpu = gpu;
		currentOutput = new h3d.pass.OutputShader();
		currentOutput.setOutput([Value("outputColor")],"outputPosition");
		reset();
		init();
	}

	function reset() {
		buttonDown = false;
		buttonDown = button();
		button2Down = false;
		button2Down = button2();
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
		if( channels != null ) {
			for( c in channels ) {
				c.c.stop();
				c.shader = null;
			}
		}
		if( data != null )
			loadData(data);
	}

	function init() {
		outTexture = new h3d.mat.Texture(WIDTH,HEIGHT,[Target]);
		outTexture.depthBuffer = new h3d.mat.Texture(WIDTH,HEIGHT,[Target],h3d.mat.Data.TextureFormat.Depth24Stencil8);
		setCamera(new h3d.Camera().mcam);
		#if hl
		sound = new hxd.snd.openal.Driver();
		#else
		sound = new hxd.snd.webaudio.Driver();
		#end
		channels = [
			for( i in 0...4 ) {
				c : new PicoChannel(sound),
				shader : null,
				output : new h3d.mat.Texture(PicoChannel.BUFFER_SIZE,1,[Target],R32F)
			}
		];
		soundRender = new h3d.pass.ScreenFx(new SoundShader());
	}

	function loadData( data : PicoData ) {
		this.data = data;
		memory = [for( i in data.memory ) new Buffer(i)];
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
	public function loadBuffer( index : Int ) : Buffer {
		return memory[index];
	}

	/**
		Load the peristent data storage with the given global name.
		This will return a 256 bytes buffer than cannot be used for GPU
		data but only be used to store save data for your app.
	**/
	public function loadStorage( name : String ) : Buffer {
		var bytes = PicoGpu.loadPrefs(name, 256);
		var b = new Buffer(null);
		b.bytes = bytes;
		return b;
	}

	/**
		Same as loadBuffer(index).getTexture()
	**/
	public function loadTexture( index : Int ) {
		return memory[index]?.getTexture();
	}

	// ---- SHADERS -----

	/**
		Set the current shader.
	**/
	public function setShader( index : Int ) {
		return setShaders([index]);
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
			sh = new LinkedShader(rt,sl,shaders);
			shaderCombi.set(key, sh);
		}
		if( currentShader != sh ) {
			currentShader = sh;
			needFlush = true;
		}
		return true;
	}

	function convert( v : Dynamic ) {
		var p = Std.downcast(v, ShaderParam);
		if( p != null ) v = @:privateAccess p.getValue();
		return v;
	}

	/**
		Set the global value. It will be accessible in shader variables with the @global qualifier.
	**/
	public function setGlobal( name : String, value : Dynamic ) {
		value = convert(value);
		renderCtx.globals.set(name, value);
	}

	/**
		Set the parameter for all current shaders. It will be accessible in shader variables with the @param qualifier.
	**/
	public function setParam( name : String, value : Dynamic ) {
		if( currentShader != null ) {
			value = convert(value);
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

	/**
		Return a random float number.
	**/
	public function rnd( max = 1.0 ) {
		return Math.random() * max;
	}

	/**
		Return a random int number.
	**/
	public function random( max : Int ) {
		return Std.random(max);
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

	/**
		Clip the render output to the given bounds.
		Use clip() to reset to default size.
	**/
	public function clip( x : Int = 0, y : Int = 0, w : Int = -1, h : Int = -1 ) {
		if( w < 0 ) w = WIDTH;
		if( h < 0 ) h = HEIGHT;
		gpu.engine.driver.setRenderZone(x,y,w,h);
	}

	/**
		Configure the stencil operation and fail/pass for either front(default) or back face.
		Use `Stencil.XXX` to access operations.
	**/
	public function stencil( op : h3d.mat.Data.StencilOp, fail : h3d.mat.Data.StencilOp, pass : h3d.mat.Data.StencilOp, front = true ) {
		if( front )
			currentMaterial.stencil.setFront(op,fail,pass);
		else
			currentMaterial.stencil.setBack(op,fail,pass);
	}

	/**
		Configure the stencil function, reference and mask values
	**/
	public function stencilFunc( comp : h3d.mat.Data.Compare, reference = 0, readMask = 0xFF, writeMask = 0xFF ) {
		currentMaterial.stencil.setFunc(comp, reference,readMask,writeMask);
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
		You can optionaly set a buffer that will act as a depth and stencil buffer.
	**/
	public function setTarget( ?t : Texture, ?depth : Buffer ) {
		if( t != null && depth != null )
			t.tex.depthBuffer = depth.getTexture(Depth24Stencil8).tex;
		gpu.engine.driver.setRenderTarget(t?.tex ?? outTexture);
		if( t != null && depth != null )
			t.tex.depthBuffer = null;
	}

	/**
		Clear the current target color, and optionaly the current depth and stencil.
	**/
	public function clear( color ) {
		gpu.engine.driver.clear(color);
	}


	/**
		Clear the current target depth, stencil, or both
	**/
	public function clearDS( ?depth : Float, ?stencil : Int ) {
		gpu.engine.driver.clear(null, depth, stencil);
	}

	/**
		Draw using the vertex buffer using the current shader. Use either triangles or specified index buffer.
	**/
	public function draw( buffer : Buffer, ?index : Buffer, ?startTri = 0, ?drawTri = -1 ) {
		if( currentShader == null ) return;
		if( buffer == null ) {
			log("Null buffer");
			return;
		}
		if( currentShader.instanceFormat != null ) {
			log("Shader needs drawInstance()");
			return;
		}
		flush();
		if( index == null )
			gpu.engine.renderTriBuffer(buffer.alloc(currentShader.format), startTri, drawTri);
		else
			gpu.engine.renderIndexed(buffer.alloc(currentShader.format), index.allocIndexes(), startTri, drawTri);
	}

	/**
		Draw a given number of instances using the data buffer and a per instance buffer.
	**/
	public function drawInstance( buffer : Buffer, instanceBuffer : Buffer, count : Int, ?index : Buffer ) {
		if( currentShader == null ) return;
		if( buffer == null ) {
			log("Null buffer");
			return;
		}
		var buf = buffer.alloc(currentShader.format);
		var ibuf = index?.allocIndexes() ?? gpu.engine.mem.getTriIndexes(buf.vertices);
		var inst = new h3d.impl.InstanceBuffer();
		inst.setCommand(count,index != null ? ibuf.count : buf.vertices);
		flush();
		var buffers = [buf];
		if( instanceBuffer != null && currentShader.instanceFormat != null )
			buffers.push(instanceBuffer.alloc(currentShader.instanceFormat));
		var fmt = hxd.BufferFormat.MultiFormat.make([for( b in buffers ) b.format]);
		gpu.engine.driver.selectMultiBuffers(fmt,buffers);
		gpu.engine.renderInstanced(ibuf, inst);
	}

	/**
		Tell which texture will be display at the end of rendering.
		Used for debug purposes;
	**/
	public function showTexture( tex : Texture ) {
		displayTex = tex;
	}

	function hasFocus() {
		// if we are editing the code, we don't have focus
		return gpu.sevents.getFocus() == null;
	}

	// --- CONTROLS ----

	/**
		Returns [-1,1] based on the keyboard left/right arrows / WASD and/or gamepad.
	**/
	public function dirX() : Float {
		var pad = gpu.pad;
		var dx = pad.xAxis;
		if( hasFocus() ) {
			if( K.isDown(K.LEFT) || K.isDown("A".code) || K.isDown("Q".code) )
				dx--;
			if( K.isDown(K.RIGHT) || K.isDown("D".code) )
				dx++;
		}
		if( pad.buttons[pad.config.dpadLeft] )
			dx--;
		if( pad.buttons[pad.config.dpadRight] )
			dx++;
		if( dx > 1 ) dx = 1;
		if( dx < -1 ) dx = -1;
		return dx;
	}

	/**
		Returns [-1,1] based on the keyboard up/down arrows / WASD and/or gamepad.
	**/
	public function dirY() : Float {
		var pad = gpu.pad;
		var dy = pad.yAxis;
		if( hasFocus() ) {
			if( K.isDown(K.UP) || K.isDown("Z".code) || K.isDown("W".code) )
				dy--;
			if( K.isDown(K.DOWN) || K.isDown("S".code) )
				dy++;
		}
		if( pad.buttons[pad.config.dpadUp] )
			dy--;
		if( pad.buttons[pad.config.dpadDown] )
			dy++;
		if( dy > 1 ) dy = 1;
		if( dy < -1 ) dy = -1;
		return dy;
	}

	/**
		Returns true if the main button is pushed (E/space on keyboard, A/X on gamepad, or mouse click)
	**/
	public function button() {
		if( hasFocus() ) {
			if( K.isDown(K.SPACE) || K.isDown("E".code) || K.isDown(K.MOUSE_LEFT) )
				return !buttonDown;
		}
		var pad = gpu.pad;
		if( pad.buttons[pad.config.A] || pad.buttons[pad.config.X] )
			return !buttonDown;
		buttonDown = false;
		return false;
	}

	/**
		Returns true if the secondary button is pushed (R/enter on keyboard, B/Y on gamepad, or mouse right click)
	**/
	public function button2() {
		if( hasFocus() ) {
			if( K.isDown(K.ENTER) || K.isDown("R".code) || K.isDown(K.MOUSE_RIGHT) )
				return !button2Down;
		}
		var pad = gpu.pad;
		if( pad.buttons[pad.config.B] || pad.buttons[pad.config.Y] )
			return !button2Down;
		button2Down = false;
		return false;
	}

	function mousePos() {
		var sc = gpu.getScene();
		var p = sc.globalToLocal(new h2d.col.Point(gpu.s2d.mouseX,gpu.s2d.mouseY));
		if( sc.width != null )
			p.scale(WIDTH / sc.width);
		return p;
	}

	/**
		Returns the mouseX position on screen.
	**/
	public function mouseX() : Int {
		return Math.round(hxd.Math.clamp(mousePos().x,0,WIDTH));
	}

	/**
		Returns the mouseY position on screen.
	**/
	public function mouseY() : Int {
		return Math.round(hxd.Math.clamp(mousePos().y,0,HEIGHT));
	}

	/**
		Return the current time since 1/1/1970 in seconds
	**/
	public function time() {
		return Std.int(Date.now().getTime() / 1000.);
	}

	/// SOUND ------

	public function setChannel( channel : Int, shader : Int ) {
		var c = channels[channel];
		if( c == null ) {
			log("Invalid channel");
			return false;
		}
		if( shader < 0 ) {
			c.c.stop();
			c.shader = null;
			return true;
		}
		var s = this.shaders[shader];
		if( s == null ) {
			log("Invalid shader index #"+shader);
			return false;
		}
		if( s.shader == null ) {
			log("Shader #"+shader+" is invalid");
			return false;
		}
		if( c.shader != s ) {
			c.c.stop();
			c.shader = s;
		}
		return true;
	}

	/// SYSTEM ------

	inline function log( v : String ) {
		gpu.logOnce(v);
	}

	function beginFrame() {
		displayTex = null;
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
		currentMaterial.stencil = new h3d.mat.Stencil();
	}

	function endFrame() {
		for( c in channels )
			if( c.c.update() ) {
				if( c.shader != null ) {
					// we don't want our time to be too high
					// or we will lose precision. Since we need about ~12 bits for buffer position
					// and a typical 32 bit float has 23 bits of mantissa, we will keep 11 bits in
					// high bits. This will loop every ~2 minutes but can be handled with `time2`
					var loop = (1 << 11) - 1;
					soundRender.shader.offset = c.c.bufferCount & loop;
					soundRender.shader.freq = PicoChannel.FREQ;
					soundRender.shader.bufferSize = PicoChannel.BUFFER_SIZE;
					soundRender.shader.highOffset = c.c.bufferCount & ~loop;
					soundRender.addShader(c.shader.shader);
					gpu.engine.driver.setRenderTarget(c.output);
					gpu.engine.driver.setRenderZone(0,0,c.output.width,c.output.height);
					renderCtx.setCurrent();
					@:privateAccess gpu.handleRuntimeError(() -> soundRender.render());
					renderCtx.clearCurrent();
					gpu.engine.driver.setRenderTarget(outTexture);
					soundRender.removeShader(c.shader.shader);
					var pix = c.output.capturePixels();
					c.c.cpuBuffer.blit(0, pix.bytes, 0, pix.dataSize);
				}
				c.c.bufferCount++;
				c.c.next();
			}
		gpu.engine.driver.setRenderZone(0,0,gpu.engine.width,gpu.engine.height);
	}

}

abstract class ShaderParam {
	abstract function getValue() : Dynamic;
}

class Buffer extends ShaderParam {
	var mem : PicoMem;
	var buffer : h3d.Buffer;
	var texture : h3d.mat.Texture;
	var ptex : Texture;
	var bytes : haxe.io.Bytes;

	/**
		The size of the buffer, in bytes
	**/
	public var length(get,never) : Int;

	function new(mem) {
		this.mem = mem;
	}

	function getValue():Dynamic {
		return alloc(hxd.BufferFormat.VEC4_DATA);
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

	public function setF32( index : Int, v : #if js Float #else Single #end ) {
		getBytes().setFloat(index << 2, v);
		dispose();
	}

	public function setVec( index : Int, v : h3d.Vector4 ) {
		var b = getBytes();
		b.setFloat(index++ << 2, v.x);
		b.setFloat(index++ << 2, v.y);
		b.setFloat(index++ << 2, v.z);
		b.setFloat(index++ << 2, v.w);
		dispose();
	}

	public function setMat( index : Int, m : h3d.Matrix ) {
		var b = getBytes();
		b.setFloat(index++ << 2, m._11);
		b.setFloat(index++ << 2, m._21);
		b.setFloat(index++ << 2, m._31);
		b.setFloat(index++ << 2, m._41);
		b.setFloat(index++ << 2, m._12);
		b.setFloat(index++ << 2, m._22);
		b.setFloat(index++ << 2, m._32);
		b.setFloat(index++ << 2, m._42);
		b.setFloat(index++ << 2, m._13);
		b.setFloat(index++ << 2, m._23);
		b.setFloat(index++ << 2, m._33);
		b.setFloat(index++ << 2, m._43);
		b.setFloat(index++ << 2, m._14);
		b.setFloat(index++ << 2, m._24);
		b.setFloat(index++ << 2, m._34);
		b.setFloat(index++ << 2, m._44);
		dispose();
	}

	public function setMat3x4( index : Int, m : h3d.Matrix ) {
		var b = getBytes();
		b.setFloat(index++ << 2, m._11);
		b.setFloat(index++ << 2, m._21);
		b.setFloat(index++ << 2, m._31);
		b.setFloat(index++ << 2, m._41);
		b.setFloat(index++ << 2, m._12);
		b.setFloat(index++ << 2, m._22);
		b.setFloat(index++ << 2, m._32);
		b.setFloat(index++ << 2, m._42);
		b.setFloat(index++ << 2, m._13);
		b.setFloat(index++ << 2, m._23);
		b.setFloat(index++ << 2, m._33);
		b.setFloat(index++ << 2, m._43);
		dispose();
	}

	function alloc(format:hxd.BufferFormat) {
		if( mem == null ) throw "Storage buffer cannot be used as GPU buffer";
		if( buffer == null || buffer.format != format ) {
			buffer?.dispose();
			var bytes = getBytes();
			buffer = new h3d.Buffer(Std.int(bytes.length/format.strideBytes),format);
			buffer.uploadBytes(bytes,0,buffer.vertices);
		}
		return buffer;
	}

	function dispose() {
		if( mem == null ) {
			PicoGpu.savePrefs();
			return;
		}
		buffer?.dispose();
		texture?.dispose();
		buffer = null;
		texture = null;
		ptex = null;
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
	public function getTexture( ?fmt ) : Texture {
		if( texture != null )
			return ptex;
		if( mem == null ) throw "Storage buffer cannot be used as Texture";
		switch( mem.data ) {
		case Unknown:
			return null;
		case Texture(_,pix):
			var sup = h3d.Engine.getCurrent().driver.isSupportedFormat(pix.format);
			var pixels = new hxd.Pixels(pix.width,pix.height,getBytes(),pix.format);
			if( !sup ) pixels.convert(RGBA);
			texture = new h3d.mat.Texture(pix.width, pix.height, [Target], pixels.format);
			texture.uploadPixels(pixels);
		default:
			var size = getBytes().length>>2;
			var width = Std.int(Math.sqrt(size));
			var height = Std.int(size/width);
			texture = new h3d.mat.Texture(width, height, [Target], fmt);
			if( fmt != Depth24Stencil8 )
				texture.uploadPixels(new hxd.Pixels(width,height,bytes,fmt ?? BGRA));
		}
		ptex = @:privateAccess new Texture(texture);
		return ptex;
	}

}

class Texture extends ShaderParam {

	public var width(get,never) : Int;
	public var height(get,never) : Int;
	public var format(get,never) : hxd.PixelFormat;

	var tex : h3d.mat.Texture;

	function new(tex:h3d.mat.Texture) {
		this.tex = tex;
		filter(false);
		wrap(true);
	}

	function get_width() {
		return tex.width;
	}

	function get_height() {
		return tex.height;
	}

	function get_format() {
		return tex.format;
	}

	function getValue() : Dynamic {
		return tex;
	}

	/**
		If true, the texture will be sampled using bilinear filtering. If false, it will get the nearest pixel. Default is false.
	**/
	public function filter( b : Bool ) {
		tex.filter = b ? Linear : Nearest;
	}

	/**
		If true, accessing the texture outside [0,1] range will wrap around. If false, it will clamp to the edges. Default is true.
	**/
	public function wrap( b : Bool ) {
		tex.wrap = b ? Repeat : Clamp;
	}

	/**
		Tells if a texture has been disposed. This can happen if the memory buffer has been modified.
	**/
	public function isDisposed() {
		return tex.isDisposed();
	}

}