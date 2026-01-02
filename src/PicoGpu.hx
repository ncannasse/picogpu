import PicoApi;

enum DispMode {
	Code;
	Shaders;
	Memory;
	Samples;
}

@:uiNoComponent @:uiInitFunction(init)
class DynamicComponent extends h2d.Flow implements h2d.domkit.Object {

	public function new(?parent) {
		super(parent);
		init();
	}

	function init() {
	}

	public function rebuild() {
		removeChildren();
		@:privateAccess dom.contentRoot = this;
		init();
	}

}

class Button extends h2d.Flow implements h2d.domkit.Object {

	static var SRC = <button>
		<text text={label}/>
	</button>

	public var selected(default, set) : Bool;

	public function new(label:String,?parent) {
		super(parent);
		initComponent();
		enableInteractive = true;
		interactive.onClick = function(_) onClick();
		interactive.onOver = function(_) dom.hover = true;
		interactive.onOut = function(_) dom.hover = false;
		interactive.onPush = function(_) dom.active = true;
		interactive.onRelease = interactive.onReleaseOutside = function(_) dom.active = false;
	}

	function set_selected(b) {
		this.selected = b;
		dom.toggleClass("sel",b);
		return b;
	}

	public dynamic function onClick() {}

}

class PicoWindow extends DynamicComponent {

	static var SRC = <pico-window>
		<flow class="header">
			<button("Code") onClick={() -> gpu.setMode(Code)} id="modes[]"/>
			<button("Shaders") onClick={() -> gpu.setMode(Shaders)} id="modes[]"/>
			<button("Memory") onClick={() -> gpu.setMode(Memory)} id="modes[]"/>
			<button("Samples") onClick={() -> gpu.setMode(Samples)} id="modes[]"/>
			<button("Run [F5]") onClick={() -> gpu.run()}/>
		</flow>
		<flow class="content">
			<flow class="code">
				<flow class="banks">
					for( i in 0...16 )
						<button(""+i) onClick={() -> gpu.setBank(i)} id="banks[]"/>
				</flow>
				<flow class="code-content">
					<text class="lineNumbers" id/>
					<input id="code" multiline={true}>
						<flow class="errorLineDisp" id/>
					</input>
					<flow class="memPanel">
						<flow class="modeSelect">
							for( i => m in ["Undef","I32","F32","Texture"] )
								<button(m) id="memModes[]" onClick={() -> gpu.setMemMode(i)}/>
						</flow>
						<flow class="modeStride">
							<button("-") onClick={() -> gpu.changeStride(-1)}/>
							<text id="strideValue"/>
							<button("+") onClick={() -> gpu.changeStride(1)}/>
						</flow>
						<text id="memTot"/>
						<button("Save") id="memSave" onClick={() -> gpu.memSave()}/>
					</flow>
					<flow class="samples">
						for( s in hxd.Res.load("samples") )
							<button("Load "+s.name.substr(0,-4)) onClick={() -> gpu.loadSample(s.name)}/>
					</flow>
				</flow>
			</flow>
			<flow class="render">
				<flow class="scene">
					<bitmap id="scene"/>
				</flow>
				<flow class="log">
					<flow class="log-content" id>
						<html-text id="log"/>
					</flow>
				</flow>
			</flow>
		</flow>
		<flow class="footer">
			<flow class="error">
				<text id="error"/>
			</flow>
			<text text={"PicoGPU v"+PicoGpu.VERSION} class="ver"/>
		</flow>
		<flow class="fullscreen">
			<bitmap id="sceneFS"/>
		</flow>
	</pico-window>

	var errorLine : Int = -1;
	var gpu : PicoGpu;

	public function new(gpu:PicoGpu,?parent) {
		this.gpu = gpu;
		super(parent);
	}

	override function init() {
		initComponent();
		code.insertTabs = "\t";
	}

	public function setError( line : Int, message : String ) {
		error.text = message;
		errorLine = line;
		error.parent.visible = true;
		errorLineDisp.visible = true;
		errorLineDisp.y = code.font.lineHeight * (errorLine - 1);
	}

	public function clearError() {
		errorLine = -1;
		error.parent.visible = false;
		errorLineDisp.visible = false;
	}

	public function hasError() {
		return errorLine != -1;
	}

	public function updateLineNumbers() {
		lineNumbers.text = [for( i => _ in code.text.split("\n") ) ""+(i+1)].join("\n");
	}

}

@:access(PicoApi)
@:access(PicoWindow)
class PicoGpu extends hxd.App {

	public static var VERSION = "0.1";
	static var GLOBALS = [
		"Key" => "hxd.Key",
		"Blend" => "h3d.mat.Blend",
		"Compare" => "h3d.mat.Compare",
		"Stencil" => "h3d.mat.StencilOp"
	];

	var win : PicoWindow;
	var api : PicoApi;
	var style : h2d.domkit.Style;
	var logText : Array<String> = [];
	var checker : hscript.Checker;
	var interp : hscript.Interp;
	var editMode : DispMode;
	var editShader : Int;
	var editMemory : Int;
	var editMemMode : Bool;
	var editStride = 4;
	var prevIndex : Int;

	var fileName = "current.gpu";

	override function init() {
		initSystem();
		load();
		initUI();
		start();
	}

	function load() {
		var content = try sys.io.File.getContent(fileName) catch( e : Dynamic ) { loadSample("Start.gpu"); return; };
		var data = new PicoData();
		data.loadText(content);
		api.loadData(data);
	}

	function save() {
		sys.io.File.saveContent(fileName, api.data.getText());
	}

	public function loadSample( name : String ) {
		var data = new PicoData();
		data.loadText(hxd.Res.load("samples/"+name).entry.getText());
		api.loadData(data);
		if( win != null ) setMode(Code);
	}

	public function setBank(i) {
		setMode(editMode, i);
	}

	function fmtSize( bytes : Int ) {
		if( bytes < 1024 )
			return bytes+"B";
		return hxd.Math.fmt(bytes/1024)+"KB";
	}

	public function changeStride( v : Int ) {
		editStride += v;
		if( editStride <= 1 ) editStride = 1;
		setMode(editMode);
	}

	public function setMode(mode,?index) {
		this.editMode = mode;
		editMemMode = false;
		win.dom.removeClass("editMemMode");
		win.dom.setClassKind("mode",mode.getName().toLowerCase());
		win.code.canEdit = true;
		win.code.clearUndo();
		switch( mode ) {
		case Code:
			win.code.text = api.data.code;
		case Shaders:
			if( index != null ) editShader = index else index = editShader;
			win.code.text = api.data.shaders[index] ?? "";
		case Memory:
			if( index != null ) editMemory = index else index = editMemory;
			var mem = api.data.memory[index];
			win.code.text = mem?.toCodeString(editStride) ?? "Uninitialize Memory. Select mode below.";
			win.code.canEdit = win.memSave.visible = mem.canEditCode();
			win.memTot.text = [
				"Size: "+fmtSize(mem.getMemSize()),
				"Code: "+fmtSize(api.data.getCodeSize()),
				"Total: "+fmtSize(api.data.getTotalSize()),
			].join("\n");
			win.strideValue.text = ""+editStride;
			for( i => b in win.memModes )
				b.selected = mem.data.getIndex() == i;
		case Samples:
		}
		for( k => b in win.modes )
			b.selected = mode.getIndex() == k;
		for( k => b in win.banks )
			b.selected = index == k;
		if( mode != Memory )
			onCodeChange();
		else {
			win.clearError();
			win.updateLineNumbers();
		}
	}

	public function setMemMode( mode : Int ) {
		if( !editMemMode ) {
			editMemMode = true;
			win.dom.addClass("editMemMode");
			return;
		}
		var mem = new PicoMem();
		mem.setMode(mode);

		function flush(force=false) {
			if( force || api.data.memory[editMemory].data.getIndex() != mode )
				api.data.memory[editMemory] = mem;
			setMode(Memory);
			onCodeChange();
		}

		switch( mem.data ) {
		case Texture(_):
			hxd.File.browse(function(sel) {
				sel.load(function(bytes) {
					var file = sel.fileName.split("\\").join("/").split("/").pop();
					var pixels = try hxd.res.Any.fromBytes(file,bytes).toImage().getPixels() catch( e : Dynamic ) { log(Std.string(e)); return; }
					mem.data = Texture(file, bytes, pixels);
					flush(true);
				});
			},{ title : "Select image", fileTypes : [{ name : "Image", extensions: ["png","jpg","jpeg","tga","dds"] }]});
			return;
		default:
		}
		flush();
	}

	public function memSave() {
		onCodeChange();
	}

	function onCodeChange() {
		try {
			try {
				win.clearError();
				var code = win.code.text;
				switch( editMode ) {
				case Code:
					api.data.code = code;
					compileCode();
				case Shaders:
					api.data.shaders[editShader] = code;
					var s = new PicoShader(editShader);
					s.setCode(code);
					api.updateShader(s);
					compileCode(); // force reinit program
				case Memory:
					var m = api.data.memory[editMemory];
					switch( m.data ) {
					case Unknown, Texture(_):
					default:
						m.parseCode(code);
						setMode(Memory); // reformat
					}
					compileCode(); // force reinit program
				case Samples:
				}
			} catch( e : hscript.Expr.Error ) {
				win.setError(e.line, e.toString());
			}
		} catch( e : hxsl.Ast.Error ) {
			var sub = api.data.shaders[editShader].substr(0,e.pos.min);
			var line = sub.split("\n").length;
			win.setError(line, e.msg);
		}
		win.updateLineNumbers();
	}

	function initSystem() {
		api = new PicoApi(this);
		api.resize(640,480);
		checker = new hscript.Checker(hscript.LiveClass.getTypes());
		switch( checker.types.resolve("PicoApi") ) {
		case TInst(c,_): checker.setGlobals(c);
		default:
		}
		for( name => cl in GLOBALS )
			switch( checker.types.resolve(cl) ) {
			case TInst(c,_):
				checker.setGlobal(name, c.staticClass);
			case TEnum(e,_):
				checker.setGlobal(name, e.enumClass);
			default:
			}
	}

	function initUI() {
		var fnt = hxd.Res.style.medodica_regular_12.toFont();
		var sp = fnt.getChar(" ".code).clone();
		sp.width *= 4;
		@:privateAccess fnt.glyphs.set("\t".code,sp);
		style = new h2d.domkit.Style();
		style.loadComponents("style");
		win = new PicoWindow(this, s2d);
		style.addObject(win);
		win.code.focus();
		#if !release
		style.allowInspect = true;
		style.watchInterpComponents();
		#end
		win.scene.tile = win.sceneFS.tile = h2d.Tile.fromTexture(api.outTexture);
		win.code.onChange = function() if( editMode == Memory ) win.updateLineNumbers() else onCodeChange();
		win.code.onKeyDown = function(e) {
			if( e.keyCode == "S".code && hxd.Key.isDown(hxd.Key.CTRL) )
				save();
		}
	}

	public function run( reset = true, fullwin = false ) {
		if( reset ) {
			compileCode();
			if( win.hasError() ) return;
		}
		win.dom.addClass("fullscreen");
		if( win.code.cursorIndex >= 0 )
			prevIndex = win.code.cursorIndex;
		win.code.blur();
		if( fullwin ) {
			engine.fullScreen = true;
			win.dom.addClass("fullwindow");
		}
	}

	function start() {
		log("Starting...");
		log("PicoGPU ready!");
		setMode(Code);
	}

	function compileCode() {
		var parser = new hscript.Parser();
		parser.allowTypes = true;
		var expr = parser.parseString(api.data.code,"");
		checker.check(expr);
		interp = new hscript.Interp();
		interp.allowTypeResolve();
		for( f in Type.getInstanceFields(Type.getClass(api)) ) {
			var v : Dynamic = Reflect.field(api,f);
			if( v != null && Reflect.isFunction(v) )
				interp.variables.set(f, Reflect.field(api,f));
		}
		interp.variables.set("trace", Reflect.makeVarArgs(function(args) {
			log(Std.string(args[0]));
		}));
		if( api.data.getTotalSize() > 64<<10 ) {
			handleRuntimeError(() -> throw "Total mem size is "+fmtSize(api.data.getTotalSize())+" >64KB");
			interp = null;
			return;
		}
		for( name => cl in GLOBALS ) {
			var t : Dynamic = Type.resolveClass(cl);
			if( t == null ) t = Type.resolveEnum(cl);
			if( t == null ) throw "assert";
			interp.variables.set(name, t);
		}
		api.reset();
		handleRuntimeError(() -> interp.execute(expr));
	}

	public function log( msg : Dynamic ) {
		logText.push(StringTools.htmlEscape(Std.string(msg)));
		while( logText.length > 500 ) logText.shift();
		win.log.text = logText.join("<br/>");
		win.logContent.scrollPosY = 100000;
	}

	public function logOnce( str : String ) {
		if( logText[logText.length-1] == StringTools.htmlEscape(str) ) return;
		log(str);
	}

	function handleRuntimeError( f ) {
		try {
			f();
		} catch( e : Dynamic ) {
			var line = @:privateAccess interp.curExpr?.line;
			logOnce(line+": "+Std.string(e));
			if( !win.hasError() )
				win.setError(line, Std.string(e));
		}
	}

	override function update(dt:Float) {
		style.sync(dt);
		engine.pushTarget(api.outTexture);
		engine.clear(0xFF000000,1,0);
		@:privateAccess api.beginFrame();
		if( interp != null ) {
			var upd : Dynamic = interp.variables.get("update");
			if( upd != null && Reflect.isFunction(upd) ) handleRuntimeError(() -> upd());
		}
		engine.popTarget();
		if( win.dom.hasClass("fullscreen") ) {
			if( hxd.Key.isPressed(hxd.Key.ESCAPE) ) {
				engine.fullScreen = false;
				win.dom.removeClass("fullscreen");
				win.dom.removeClass("fullwindow");
				style.sync(0);
				if( prevIndex < 0 ) prevIndex = 0;
				win.code.cursorIndex = prevIndex;
				win.code.focus();
			}
		} else {
			if( hxd.Key.isPressed(hxd.Key.F11) )
				run(false);
			for( i in 0...4 )
				if( hxd.Key.isPressed(hxd.Key.F1+i) )
					win.modes[i].onClick();
		}
		if( hxd.Key.isPressed(hxd.Key.F5) )
			run(true,hxd.Key.isDown(hxd.Key.CTRL));
	}

	static function main() {
		hxd.res.Resource.LIVE_UPDATE = true;
		hxd.Res.initLocal();
		new PicoGpu();
	}

}