#include "Vsimtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
        Verilated::commandArgs(argc, argv);
	Vsimtop* top = new Vsimtop;
	Verilated::traceEverOn(true);
	VerilatedVcdC* vcd= new VerilatedVcdC;
	top->trace(vcd, 99);
	vcd->open("trace.vcd");

	int cycles = 1000;
	int cycleno = 1;
	while (cycles > 0) {
		top->eval();
		if (vcd) {vcd->dump(cycleno * 10 - 2);}
		top->clk = 1;
		top->eval();
		if (vcd) {vcd->dump(cycleno * 10);}
		top->clk = 0;
		top->eval();
		if (vcd) {
			vcd->dump(cycleno* 10 + 5);
			vcd->flush();
		}
		cycles --;
		cycleno ++;
	}
	
}

