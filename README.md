# UART Verification Project

8-bit UART (2400 baud, 50 MHz) — RTL design + directed testbench.

## Structure
```
uart/
├── README.md
├── docs/
│   ├── test_plan.md
│   └── verification_report.md
└── src/
    ├── design/
    │   └── uart.v
    └── test_bench/
        └── uart_tb.v
```

## Quick Start (Icarus Verilog)
```bash
iverilog -o sim.out src/design/uart.v src/test_bench/uart_tb.v
vvp sim.out
gtkwave uart_tb.vcd
```

## Results
- 23 / 23 test cases pass
- Full TX + RX FSM coverage including reset, false-start, bad stop-bit

