# UART Verification Report

## 1. Project Information
| Field       | Value                            |
|-------------|----------------------------------|
| Module      | uart (8-bit, 2400 baud, 50 MHz)  |
| Testbench   | uart_tb.v                        |
| Simulator   | Icarus Verilog / ModelSim        |
| Date        | 2026-05-21                       |
| Parameters  | b=8, CLK_VALUE=651, BIT_CLKS=10416 |

---

## 2. Execution Summary
| Metric        | Value  |
|---------------|--------|
| Total TCs     | 23     |
| PASS          | 23     |
| FAIL          | 0      |
| NOT RUN       | 0      |
| **Pass Rate** | **100%** |

---

## 3. Results by Category
| Category        | TCs | Pass | Fail |
|-----------------|-----|------|------|
| Reset           | 4   | 4    | 0    |
| TX Basic        | 3   | 3    | 0    |
| TX Edge         | 2   | 2    | 0    |
| TX Idle         | 1   | 1    | 0    |
| TX Back-to-back | 1   | 1    | 0    |
| TX Timing       | 1   | 1    | 0    |
| RX Basic        | 3   | 3    | 0    |
| RX Edge         | 2   | 2    | 0    |
| RX Error        | 2   | 2    | 0    |
| RX Back-to-back | 1   | 1    | 0    |
| Reset during TX | 3   | 3    | 0    |
| Reset during RX | 1   | 1    | 0    |

---

## 4. Detailed Test Results

| TC # | Test Name                        | Result | Notes                                          |
|------|----------------------------------|--------|------------------------------------------------|
| TC1  | Reset state verification         | PASS   | All outputs in safe default state              |
| TC2  | TX 0x55 (alternating-1)          | PASS   | Every bit position toggled                     |
| TC3  | TX 0xAA (alternating-0)          | PASS   | Complement of TC2                              |
| TC4  | TX 0x00 (all zeros)              | PASS   | Min mark density; stop bit still high          |
| TC5  | TX 0xFF (all ones)               | PASS   | Max mark density                               |
| TC6  | TX 0xA5 (mixed)                  | PASS   |                                                |
| TC7  | TX IDLE no-op                    | PASS   | IDLE self-loop confirmed                       |
| TC8  | RX 0x55                          | PASS   |                                                |
| TC9  | RX 0xAA                          | PASS   |                                                |
| TC10 | RX 0x00                          | PASS   |                                                |
| TC11 | RX 0xFF                          | PASS   |                                                |
| TC12 | RX 0xA5                          | PASS   |                                                |
| TC13 | False start rejected             | PASS   | Glitch < 4×CLK_VALUE ignored correctly        |
| TC14 | Bad stop bit not latched         | PASS   | rec_readyH stays 0; framing error detected     |
| TC15 | Back-to-back TX 0x12, 0x34       | PASS   | STOP→IDLE→START with no gap                   |
| TC16 | Back-to-back RX 0xBE, 0xEF       | PASS   |                                                |
| TC17 | Reset during TX START            | PASS   | FSM returned to IDLE cleanly                   |
| TC18 | Reset during TX DATA             | PASS   | FSM returned to IDLE cleanly                   |
| TC19 | Reset during TX STOP             | PASS   | FSM returned to IDLE cleanly                   |
| TC20 | Reset during RX DATAOUT          | PASS   | FSM returned to IDLE cleanly                   |
| TC21 | TX immediately after reset 0xC3  | PASS   | FSM initialises correctly post-reset           |
| TC22 | RX immediately after reset 0x3C  | PASS   | FSM initialises correctly post-reset           |
| TC23 | xmitH held across clk_enables    | PASS   | Single frame only; no double-trigger           |

---

## 5. FSM Coverage Summary

### TX FSM — All transitions covered ✓
| Transition         | Covered By               |
|--------------------|--------------------------|
| IDLE → IDLE        | TC7                      |
| IDLE → START       | TC2–TC6, TC15, TC21      |
| START → DATA       | TC2–TC6                  |
| DATA → DATA (×7)   | TC2–TC6 (all 8 bits)     |
| DATA → STOP        | TC2–TC6                  |
| STOP → IDLE        | TC2–TC6                  |
| Any → IDLE (reset) | TC17, TC18, TC19         |

### RX FSM — All transitions covered ✓
| Transition              | Covered By               |
|-------------------------|--------------------------|
| IDLE → START            | TC8–TC12, TC16, TC22     |
| START → IDLE (false st) | TC13                     |
| START → DATAOUT         | TC8–TC12                 |
| DATAOUT → DATAOUT (×7)  | TC8–TC12                 |
| DATAOUT → STOP          | TC8–TC12                 |
| STOP → IDLE (valid)     | TC8–TC12                 |
| STOP → IDLE (bad stop)  | TC14                     |
| Any → IDLE (reset)      | TC20                     |

---

## 6. Observations & Recommendations
- `xmitH` must be held until the next `clk_enable` pulse for the IDLE→START transition to be latched by the TX FSM.
- False-start rejection correctly filters glitches narrower than 4×CLK_VALUE sys_clks (half of the half-bit period).
- Bad stop-bit framing error suppresses `rec_readyH`; host software must handle this by discarding the byte and re-syncing.
- `xmitH` is internally edge-qualified — holding it high across multiple `clk_enable` pulses does not cause a double-start (TC23).
- **Recommended future tests:** parity bit support, baud-rate tolerance sweep (±2%), noise injection on `uart_REC_dataH`.
