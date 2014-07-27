# either add spcomp to your system path or add the full location to it here as SMC
SMC = spcomp
FLAGS = "-O2 -t4"
SRC = csgo/addons/sourcemod/scripting/multi1v1.sp csgo/addons/sourcemod/scripting/example.sp

build: clean
	mkdir -p csgo/addons/sourcemod/plugins
	$(SMC) csgo/addons/sourcemod/scripting/multi1v1.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/multi1v1
	$(SMC) csgo/addons/sourcemod/scripting/example.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/example

clean:
	rm -rf *.smx *.zip csgo/addons/sourcemod/configs csgo/addons/sourcemod/plugins

package: build
	zip -r multi1v1 csgo web LICENSE README.md
