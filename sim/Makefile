# QuestaSim Makefile for the SPI learning project.
# Run from the repository root with: make -C sim <target>

VLIB ?= vlib
VLOG ?= vlog
VSIM ?= vsim

WORK_LIB  := work
RTL_FILES := ../rtl/spi_master.v ../rtl/spi_slave.v
TB_FILES  := ../tb/tb_spi_master.v ../tb/tb_spi_slave.v \
	../tb/tb_spi_loopback.v

# Used by `make gui`. For loopback, MODE selects SPI mode 0, 1, 2, or 3.
TEST ?= master
MODE ?= 0
TOP  := tb_spi_$(TEST)

MODE_CPOL_0 := 0
MODE_CPHA_0 := 0
MODE_CPOL_1 := 0
MODE_CPHA_1 := 1
MODE_CPOL_2 := 1
MODE_CPHA_2 := 0
MODE_CPOL_3 := 1
MODE_CPHA_3 := 1

GUI_MODE_ARGS := $(if $(filter loopback,$(TEST)),\
	-gCPOL=$(MODE_CPOL_$(MODE)) -gCPHA=$(MODE_CPHA_$(MODE)))

.PHONY: all compile master slave loopback modes mode0 mode1 mode2 mode3 \
	gui clean help

all: master slave modes

compile: $(WORK_LIB)
	$(VLOG) -work $(WORK_LIB) $(RTL_FILES) $(TB_FILES)

$(WORK_LIB):
	$(VLIB) $(WORK_LIB)

master: compile
	$(VSIM) -c -quiet $(WORK_LIB).tb_spi_master \
		-do "run -all; quit -f"

slave: compile
	$(VSIM) -c -quiet $(WORK_LIB).tb_spi_slave \
		-do "run -all; quit -f"

loopback: modes

modes: mode0 mode1 mode2 mode3

mode0: compile
	$(VSIM) -c -quiet $(WORK_LIB).tb_spi_loopback \
		-gCPOL=0 -gCPHA=0 -do "run -all; quit -f"

mode1: compile
	$(VSIM) -c -quiet $(WORK_LIB).tb_spi_loopback \
		-gCPOL=0 -gCPHA=1 -do "run -all; quit -f"

mode2: compile
	$(VSIM) -c -quiet $(WORK_LIB).tb_spi_loopback \
		-gCPOL=1 -gCPHA=0 -do "run -all; quit -f"

mode3: compile
	$(VSIM) -c -quiet $(WORK_LIB).tb_spi_loopback \
		-gCPOL=1 -gCPHA=1 -do "run -all; quit -f"

gui: compile
	$(VSIM) -voptargs=+acc $(WORK_LIB).$(TOP) $(GUI_MODE_ARGS) -do wave.do

clean:
	rm -rf $(WORK_LIB) transcript vsim.wlf \
		tb_spi_master.vcd tb_spi_slave.vcd tb_spi_loopback.vcd

help:
	@echo "QuestaSim targets:"
	@echo "  make all             Run all three testbenches"
	@echo "  make master          Run tb_spi_master in batch mode"
	@echo "  make slave           Run tb_spi_slave in batch mode"
	@echo "  make loopback        Run loopback in all four SPI modes"
	@echo "  make mode0|mode1|mode2|mode3  Run one loopback SPI mode"
	@echo "  make gui             Open master test with wave.do"
	@echo "  make gui TEST=slave  Open slave test with wave.do"
	@echo "  make gui TEST=loopback MODE=3  Open loopback Mode 3"
	@echo "  make clean           Remove generated simulation files"
