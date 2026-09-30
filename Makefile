.PHONY: test compile

test:
	haxe tests.hxml

compile:
	haxe -cp src --macro "include('reels')" --no-output -D analyzer-optimize
