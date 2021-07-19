package main

import (
	"fmt"
)

//#include "shim_binding.h"
//#include "shim.h"
import "C"

func main() {
	argc := C.int(1)
	argv := make([]*C.char, 1)
	argv[0] = C.CString("gui")
	s := C.initialize_simulation(argc, &(argv[0]), C.CString("trace.vcd"))

	for i := 0; i < 100; i++ {
		C.run_cycles(s, 1)
		fmt.Printf("cycleno: %d, foo=%d\n", s.cycleno, C.get_foo(s))
	}

}
