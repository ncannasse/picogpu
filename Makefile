
build:
	haxe picogpu.hxml
	haxe picogpu_js.hxml
	
install:
	npm install
	
www:
	npm run doc:build
	
test:
	npm run doc:test

OUT=picogpu
HL=$(HLPATH)
WINDLL=C:/Windows/System32
HDLLS=$(HL)/libhl.dll $(HL)/sdl.hdll $(HL)/fmt.hdll $(HL)/ssl.hdll $(HL)/ui.hdll $(HL)/uv.hdll $(HL)/heaps.hdll
WDLLS=$(HL)/OpenAL32.dll $(HL)/SDL2.dll $(WINDLL)/msvcp140.dll $(WINDLL)/vcruntime140.dll $(WINDLL)/vcruntime140_1.dll

release:
	rm -rf $(OUT)
	mkdir $(OUT)
	cp picogpu.hl $(OUT)/hlboot.dat
	cp -r res $(OUT)
	cp api.xml $(OUT)
	cp $(HL)/hl.exe $(OUT)/picogpu.exe
	cp $(HDLLS) $(WDLLS) $(OUT)
