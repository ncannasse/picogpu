import hxd.Key in K;

typedef CodeCompletion = {
	var name : String;
	var ?info : String;
}

class CodeTip extends h2d.Flow implements h2d.domkit.Object {
	static var SRC = <code-tip></code-tip>;
	public var select(default,set) : Int = -1;
	public var tips : Array<h2d.Flow> = [];
	function set_select(v) {
		if( select >= 0 )
			tips[select].dom.removeClass("sel");
		this.select = v;
		if( select >= 0 )
			tips[select].dom.addClass("sel");
		return v;
	}

	override function sync(ctx:h2d.RenderContext) {
		super.sync(ctx);
		if( select >= 0 ) scrollIntoView(tips[select]);
	}

}

class CodeEditor extends h2d.TextInput implements h2d.domkit.Object {

	static var SRC = <code-editor></code-editor>;

	var style : h2d.domkit.Style;
	var currentTip : CodeTip;
	var compFilter : String;
	var lastCompletion : Array<CodeCompletion>;
	var autoInsert : String;

	public var matchingInserts = ["{" => "}", "(" => ")", "[" => "]"];

	public function new(style:h2d.domkit.Style,?parent) {
		this.style = style;
		super(hxd.res.DefaultFont.get(),parent);
		initComponent();
	}

	function removeCompletion() {
		if( currentTip == null ) return;
		currentTip.remove();
		style.removeObject(currentTip);
		currentTip = null;
		lastCompletion = null;
	}

	function updateCompletion( canReset=false ) {
		var compl = getCompletion(getTextPos(cursorIndex));
		if( compl == null ) {
			if( canReset || lastCompletion == null ) {
				removeCompletion();
				return;
			}
			compl = lastCompletion;
		}
		removeCompletion();
		var pos = getTextPos(cursorIndex);
		var prev = getTextPos(getWordStart());
		compFilter = text.substr(prev, pos - prev);
		if( StringTools.endsWith(compFilter,".") )
			compFilter = "";
		var tip = new CodeTip(getScene());
		lastCompletion = [];
		for( c in compl ) {
			if( !StringTools.startsWith(c.name,compFilter) )
				continue;
			tip.tips.push(domkit.Component.build(
				<flow class="c">
					<html-text class="name" text={c.name}/>
				</flow>
			, tip));
			lastCompletion.push(c);
		}
		style.addObject(tip);
		currentTip = tip;
		if( tip.tips.length == 0 )
			removeCompletion();
		else
			tip.select = 0;
	}

	override function onBlur() {
		super.onBlur();
		removeCompletion();
	}

	override function onCursorChange() {
		super.onCursorChange();
		removeCompletion();
	}

	override function draw(ctx) {
		super.draw(ctx);
		if( currentTip != null ) {
			currentTip.x = absX + cursorX - scrollX + cursorTile.dx;
			currentTip.y = absY + cursorY + cursorTile.dy + cursorTile.height;
		}
	}

	override function handleKey(e:hxd.Event) {
		var checkCompletion = false;
		var c = currentTip;
		if( c != null ) {
			switch( e.keyCode ) {
			case K.BACKSPACE, K.DELETE:
				checkCompletion = true;
			case K.UP:
				if( c.select > 0 ) c.select--;
				return;
			case K.DOWN:
				if( c.select < c.tips.length-1 ) c.select++;
				return;
			case K.PGDOWN, K.PGUP:
				var lines = Std.int(@:privateAccess c.calculatedHeight/c.tips[0].getBounds().height);
				if( e.keyCode == K.PGUP && c.select > 0 ) {
					var n = c.select - lines;
					if( n < 0 ) n = 0;
					c.select = n;
				}
				if( e.keyCode == K.PGDOWN && c.select < c.tips.length - 1 ) {
					var n = c.select + lines;
					if( n >= c.tips.length ) n = c.tips.length - 1;
					c.select = n;
				}
				return;
			case K.ESCAPE:
				removeCompletion();
				return;
			case K.TAB, K.ENTER:
				inputText("");
				return;
			default:
			}
		}
		super.handleKey(e);
		if( checkCompletion ) updateCompletion();
	}

	override function inputText(t:String) {
		if( autoInsert != null ) {
			/*
				If we type something that was auto-inserted, we will simply move the cursor
				Exemple : ( inserts a )
			*/
			if( StringTools.startsWith(autoInsert,t) ) {
				autoInsert = autoInsert.substr(t.length);
				if( autoInsert == "" ) autoInsert = null;
				cursorIndex += t.length;
				onChange();
				return;
			}
			autoInsert = null;
		}
		// auto trigger complete when inserting something
		if( currentTip != null && (t.length == 0 || (t.length == 1 && !~/[A-Za-z-0-9_]/.match(t))) ) {
			var comp = lastCompletion[currentTip.select].name;
			removeCompletion();
			beforeChange();
			selectionRange = { start : cursorIndex - compFilter.length, length : compFilter.length };
			inputText(comp);
		}
		var prevLine = t == "\n" ? getCurrentLine() : null;
		super.inputText(t);
		// auto insert matching parent/brace
		var extra = matchingInserts.get(t);
		if( extra != null ) {
			var prev = cursorIndex;
			super.inputText(extra);
			cursorIndex = prev;
			onChange();
			autoInsert = extra;
		}
		// keep previous line identation
		if( t == "\n" && prevLine != null ) {
			var ident = ~/^[ \t]+/;
			if( ident.match(prevLine.value) )
				super.inputText(ident.matched(0));
		}
	}

	public function setCode( code : String ) {
		text = code;
		removeCompletion();
	}

	override dynamic function onChange() {
		updateCompletion();
		onCodeChange();
	}

	public dynamic function onCodeChange() {
	}

	public dynamic function getCompletion( position : Int ) : Null<Array<CodeCompletion>> {
		return null;
	}

}
