
build:
	haxe picogpu.hxml
	haxe picogpu_js.hxml
	
install:
	npm install
	
www:
	npm run doc:build
	
test:
	npm run doc:test

