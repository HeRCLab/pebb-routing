#ifndef SHIM_H
#define SHIM_H

#ifdef __cplusplus
#include "Vsimtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#else
#define Vsimtop void
#define VerilatedVcdC void
#endif

#include "stdint.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct simulation_state_t {
	Vsimtop* top;
	VerilatedVcdC* vcd;
	uint64_t cycleno;
} simulation_state;

simulation_state* initialize_simulation(int argc, char** argv, char* trace_file);
void run_cycles(simulation_state* s, uint64_t cycles);

#ifdef __cplusplus
}
#endif

#endif
