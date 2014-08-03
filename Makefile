# either add spcomp to your system path or add the full location to it here as SMC
SMC = spcomp
FLAGS = "-O2 -t4"

build: clean
	mkdir -p csgo/addons/sourcemod/plugins
	$(SMC) csgo/addons/sourcemod/scripting/multi1v1.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/multi1v1
	$(SMC) csgo/addons/sourcemod/scripting/multi1v1_sprweight.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/disabled/multi1v1_sprweight
	$(SMC) csgo/addons/sourcemod/scripting/multi1v1_elomatcher.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/disabled/multi1v1_elomatcher
	$(SMC) csgo/addons/sourcemod/scripting/multi1v1_quietmode.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/disabled/multi1v1_quietmode

test: clean
	mkdir -p csgo/addons/sourcemod/plugins
	$(SMC) csgo/addons/sourcemod/scripting/multi1v1_test.sp ${FLAGS} -o=csgo/addons/sourcemod/plugins/multi1v1_test

clean:
	rm -rf *.smx *.zip csgo/addons/sourcemod/configs csgo/addons/sourcemod/plugins

package: build
	zip -r multi1v1 csgo web LICENSE README.md
