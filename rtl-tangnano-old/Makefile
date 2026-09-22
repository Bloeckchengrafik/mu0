.PHONY: build upload docker

SOURCES=src/comm.v src/uart.v src/mux.v src/mu0.v src/memory.v src/alu.v src/main.v

build: $(SOURCES)
	mkdir -p build
	rm -rf build
	mkdir build
	yosys -p "read_verilog $(SOURCES) ; synth_gowin -json build/main.json"
	nextpnr-himbaechel --json build/main.json --write build/main_pnr.json --device GW1NR-LV9QN88PC6/I5 --vopt family=GW1N-9C --vopt cst=tangnano9k.cst
	gowin_pack -d GW1N-9C -o build/pack.fs build/main_pnr.json

upload:
	openFPGALoader -b tangnano9k build/pack.fs

upload-nv:
	openFPGALoader -b tangnano9k -f build/pack.fs

run:
	docker run -v .:/mnt/app -w /mnt/app -it cbergschneider/gowinc make build
	make upload

run-nv:
	docker run -v .:/mnt/app -w /mnt/app -it cbergschneider/gowinc make build
	make upload-nv

test_uart:
	mkdir -p test
	iverilog -o test/uart_test.o -s uart_tb src/uart.v testbenches/uart_tb.v
	cd test/ && vvp uart_test.o

test_mux:
	mkdir -p test
	iverilog -o test/mux_test.o -s mux_tb src/mux.v testbenches/mux_tb.v
	cd test/ && vvp mux_test.o

test_memory:
	mkdir -p test
	iverilog -o test/memory_test.o -s memory_tb src/memory.v testbenches/memory_tb.v
	cd test/ && vvp memory_test.o


test_alu:
	mkdir -p test
	iverilog -o test/alu_test.o -s alu_tb src/alu.v testbenches/alu_tb.v
	cd test/ && vvp alu_test.o

tests: test_uart test_mux test_memory test_alu
