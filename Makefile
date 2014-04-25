# either add spcomp to your system path or add the full location to it here as SMC
SMC = spcomp
FLAGS = "-O2 -t4"
SRC = csgo/addons/sourcemod/scripting/multi1v1.sp
OUT = csgo/addons/sourcemod/plugins/multi1v1
CFG = csgo/cfg/sourcemod/multi1v1.cfg
TRANS = csgo/addons/sourcemod/translations
BINARY = csgo/addons/sourcemod/plugins/multi1v1.smx

build: clean
	mkdir -p csgo/addons/sourcemod/plugins
	$(SMC) ${SRC} ${FLAGS} -o=${OUT}

clean:
	rm -rf *.smx *.zip

package: build
	zip -r multi1v1 csgo
