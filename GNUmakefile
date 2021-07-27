include ./opinionated.mk

VERILATOR=verilator
VERILATOR_ROOT=$(shell bash -c 'verilator -V | grep VERILATOR_ROOT | head -1 | sed -e "s/^.*=\s*//"')
VERILATOR_INC=$(VERILATOR_ROOT)/include

PROJECT_DIR=$(shell realpath .)

RTL_DIR=$(PROJECT_DIR)/rtl
SIM_DIR=$(PROJECT_DIR)/sim
TB_DIR=$(PROJECT_DIR)/tb

# Used for SIM= for cocotb
TEST_SIMULATOR=icarus
TB_DIRS=$(shell find $(TB_DIR) -type f -name "Makefile" -exec dirname {} \;)
TB_DONEFILES=$(shell find $(TB_DIR) -type f -name "Makefile" -exec dirname {} \; | awk '{printf("%s.done", $$0)}')

SV_FILES=$(shell find $(RTL_DIR) -type f -iname "*.sv")
H_FILES=$(shell find $(SIM_DIR) -type f -iname "*.h")
GO_FILES=$(shell find $(SIM_DIR) -type f -iname "*.go")
PY_TB_FILES=$(shell find $(TB_DIR) -type f -iname "*.py")


BUILD_DIR=$(PROJECT_DIR)/build
OBJ_DIR=$(BUILD_DIR)/obj
VERILATOR_OBJ_DIR=$(BUILD_DIR)/verilator_obj
BIN_DIR=$(BUILD_DIR)/bin
LIB_DIR=$(BUILD_DIR)/lib
GENERATED_DIR=$(BUILD_DIR)/generated

OBJECTS=$(OBJ_DIR)/verilated.o \
	$(OBJ_DIR)/verilated_vcd_c.o \
	$(OBJ_DIR)/main.o \
	$(OBJ_DIR)/shim.o \
	$(OBJ_DIR)/shim_binding.o

# CGo seems to prefer using .a files.
ARCHIVES=$(LIB_DIR)/libsimulation.a \
	 $(LIB_DIR)/libshim.a \
	 $(LIB_DIR)/libshim_binding.a \
	 $(LIB_DIR)/libverilated.a \
	 $(LIB_DIR)/libverilated_vcd_c.a

SIM_ARCHIVE=$(VERILATOR_OBJ_DIR)/Vsimtop__ALL.a

CC=gcc
CXX=g++
C_INCLUDES=-I$(GENERATED_DIR) -I$(VERILATOR_INC) -I$(VERILATOR_OBJ_DIR) -I$(SIM_DIR)
CFLAGS=-Wall -Wextra $(C_INCLUDES)
CXXFLAGS=--std=c++17 $(CFLAGS)

test: $(TB_DONEFILES) $(PY_TB_FILES)
.PHONY: test

$(TB_DIR)/%.done: $(TB_DIR)/%/Makefile $(SV_FILES) $(PY_TB_FILES)
> sh -c 'cd "'"$$(echo "$@" | sed s/.done//g)"'/"; make SIM='"$(TEST_SIMULATOR)"';'
> touch $@

$(BIN_DIR)/sim: $(GO_FILES) $(H_FILES) $(ARCHIVES) $(GENERATED_DIR)/shim_binding.cpp
> CGO_CFLAGS="-I temp_include $(C_INCLUDES)" CGO_LDFLAGS="-L$(LIB_DIR) -lshim -lshim_binding -lsimulation -lverilated -lverilated_vcd_c -lstdc++ -lm" go build -o "$@" "$<"

$(LIB_DIR)/libsimulation.a: $(SIM_ARCHIVE) .builddirs.done
> cp "$<" "$@"

$(LIB_DIR)/lib%.a: $(OBJ_DIR)/%.o
> ar r "$@" $^

.builddirs.done:
> mkdir -p $(OBJ_DIR)
> mkdir -p $(BIN_DIR)
> mkdir -p $(LIB_DIR)
> mkdir -p $(GENERATED_DIR)
> touch $@

$(OBJ_DIR)/%.o: $(VERILATOR_INC)/%.cpp .builddirs.done
> $(CXX) $(CXXFLAGS) -c $< -o $@

$(SIM_ARCHIVE): $(VERILATOR_OBJ_DIR)/Vsimtop.cpp .builddirs.done
> $(MAKE) -C $(VERILATOR_OBJ_DIR) -f Vsimtop.mk

$(VERILATOR_OBJ_DIR)/Vsimtop.cpp: $(SV_FILES) .builddirs.done
> $(VERILATOR) --Mdir "$(VERILATOR_OBJ_DIR)" -I$(RTL_DIR) --trace -cc $(RTL_DIR)/simtop.sv

$(OBJ_DIR)/%.o: $(SIM_DIR)/%.cpp $(SIM_ARCHIVE) $(H_FILES) $(GENERATED_DIR)/shim_binding.cpp
> $(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(GENERATED_DIR)/%.cpp $(SIM_ARCHIVE) $(H_FILES)
> $(CXX) $(CXXFLAGS) -c $< -o $@

$(GENERATED_DIR)/shim_binding.cpp: $(SIM_ARCHIVE) genbinding.awk .builddirs.done
> awk -f genbinding.awk < $(VERILATOR_OBJ_DIR)/Vsimtop.h > $@ 2> $(GENERATED_DIR)/shim_binding.h


clean:
> for t in $(TB_DIRS) ; do echo sh -c 'cd "'"$$t"'"; make clean;' ; done
> for t in $(TB_DIRS) ; do sh -c 'cd "'"$$t"'"; rm -f *.xml *.vcd' ; done
> for t in $(TB_DIRS) ; do sh -c 'cd "'"$$t"'"; rm -rf __pycache__' ; done
> for t in $(TB_DIRS) ; do sh -c 'cd "'"$$t"'"; rm -rf sim_build' ; done
> rm -f $(TB_DONEFILES)
> rm -rf $(BUILD_DIR)
> rm -f .builddirs.done
.PHONY: clean
