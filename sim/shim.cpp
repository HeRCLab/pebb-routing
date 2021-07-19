/* we don't include these under c, since it will confuse cgo */
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

simulation_state* initialize_simulation(int argc, char** argv, char* trace_file) {
	Verilated::commandArgs(argc, argv);
	simulation_state* s = (simulation_state*) malloc(sizeof(simulation_state));
	if (s == NULL) {
		return NULL;
	}
	s->top = new Vsimtop;
	Verilated::traceEverOn(true);
	s->vcd = new VerilatedVcdC;
	s->top->trace(s->vcd, 99);
	s->vcd->open(trace_file);
	s->cycleno = 1;
	return s;
}

/* Run the simulation the given number of cycles */
void run_cycles(simulation_state* s, uint64_t cycles)  {

	while (cycles > 0) {
		s->top->eval();
		if (s->vcd) { s->vcd->dump(s->cycleno * 10 - 2); }
		s->top->clk = 1;
		s->top->eval();
		if (s->vcd) { s->vcd->dump(s->cycleno * 10); }
		s->top->clk = 0;
		s->top->eval();
		if (s->vcd) {
			s->vcd->dump(s->cycleno * 10 + 5);
			s->vcd->flush();
		}
		cycles --;
		s->cycleno++;
	}
}


#ifdef __cplusplus
}
#endif
