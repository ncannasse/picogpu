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