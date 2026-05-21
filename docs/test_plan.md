# UART Verification Test Plan

## 1. Overview
| Field      | Value                        |
|------------|------------------------------|
| Module     | uart                         |
| Testbench  | uart_tb                      |
| Baud Rate  | 2400                         |
| Clock      | 50 MHz (20 ns period)        |
| Data Bits  | 8                            |
| CLK_VALUE  | 651 sys_clks per baud tick   |
| BIT_CLKS   | 10,416 sys_clks per UART bit |

---

## 2. Features Under Test
- TX FSM: IDLE → START → DATA (×8) → STOP → IDLE
- RX FSM: IDLE → START → DATAOUT (×8) → STOP → IDLE
- Baud-rate clock enable generation (`clk_enable`)
- Asynchronous active-low reset (`sys_rst_l`)
- False-start glitch rejection (START → IDLE when F2≠0 at count==7)
- Bad stop-bit framing error (STOP: F2==0 branch)
- Back-to-back TX and RX frames

---

## 3. Test Cases

| TC # | Category         | Test Name                        | FSM Transition                  | Pass Criteria                                          |
|------|------------------|----------------------------------|---------------------------------|--------------------------------------------------------|
| TC1  | Reset            | Reset state verification         | Any → IDLE (both FSMs)          | xmit_doneH=1, xmit_active=0, rec_readyH=1, rec_busy=0 |
| TC2  | TX Basic         | TX 0x55 (alternating-1)          | IDLE→START→DATA×8→STOP→IDLE     | xmit_doneH==1 within 2,000,000 sys_clks                |
| TC3  | TX Basic         | TX 0xAA (alternating-0)          | IDLE→START→DATA×8→STOP→IDLE     | xmit_doneH==1 within timeout                           |
| TC4  | TX Edge          | TX 0x00 (all zeros)              | DATA state: all bits=0          | xmit_doneH==1 within timeout                           |
| TC5  | TX Edge          | TX 0xFF (all ones)               | DATA state: all bits=1          | xmit_doneH==1 within timeout                           |
| TC6  | TX Basic         | TX 0xA5 (mixed)                  | IDLE→START→DATA×8→STOP→IDLE     | xmit_doneH==1 within timeout                           |
| TC7  | TX Idle          | xmitH=0 stays IDLE               | IDLE→IDLE                       | xmit_active==0 AND xmit_doneH==1                       |
| TC8  | RX Basic         | RX 0x55                          | IDLE→START→DATAOUT×8→STOP→IDLE  | rec_readyH==1 AND rec_dataH==0x55                      |
| TC9  | RX Basic         | RX 0xAA                          | IDLE→START→DATAOUT×8→STOP→IDLE  | rec_readyH==1 AND rec_dataH==0xAA                      |
| TC10 | RX Edge          | RX 0x00                          | DATAOUT: all bits=0             | rec_readyH==1 AND rec_dataH==0x00                      |
| TC11 | RX Edge          | RX 0xFF                          | DATAOUT: all bits=1             | rec_readyH==1 AND rec_dataH==0xFF                      |
| TC12 | RX Basic         | RX 0xA5                          | IDLE→START→DATAOUT×8→STOP→IDLE  | rec_readyH==1 AND rec_dataH==0xA5                      |
| TC13 | RX Error         | False start rejected             | START→IDLE (F2≠0 at count==7)   | rec_busy==0 AND rec_readyH==1                          |
| TC14 | RX Error         | Bad stop bit not latched         | STOP: F2==0 branch              | rec_readyH==0 (framing error, data not latched)        |
| TC15 | TX Back-to-back  | TX 0x12 then 0x34                | STOP→IDLE→START (consecutive)   | xmit_doneH==1 twice, both within timeout               |
| TC16 | RX Back-to-back  | RX 0xBE then 0xEF                | STOP→IDLE→START (consecutive)   | rec_dataH correct AND rec_readyH==1 twice              |
| TC17 | Reset during TX  | Reset in TX START state          | START → IDLE (async reset)      | xmit_active==0 AND xmit_doneH==1 after de-assert       |
| TC18 | Reset during TX  | Reset in TX DATA state           | DATA → IDLE (async reset)       | xmit_active==0 AND xmit_doneH==1 after de-assert       |
| TC19 | Reset during TX  | Reset in TX STOP state           | STOP → IDLE (async reset)       | xmit_active==0 AND xmit_doneH==1 after de-assert       |
| TC20 | Reset during RX  | Reset in RX DATAOUT state        | DATAOUT → IDLE (async reset)    | rec_busy==0 AND rec_readyH==1 after de-assert          |
| TC21 | Reset            | TX immediately after reset 0xC3  | IDLE→START post-reset           | xmit_doneH==1 within timeout                           |
| TC22 | Reset            | RX immediately after reset 0x3C  | IDLE→START post-reset           | rec_readyH==1 AND rec_dataH==0x3C                      |
| TC23 | TX Timing        | xmitH held across clk_enables    | Single IDLE→START, no re-trig   | xmit_doneH==1 once only; no second start bit           |

---

## 4. FSM Coverage Matrix

### TX FSM
| Transition         | TCs Covering              |
|--------------------|---------------------------|
| IDLE → IDLE        | TC7                       |
| IDLE → START       | TC2–TC6, TC15, TC21       |
| START → DATA       | TC2–TC6                   |
| DATA → DATA (×7)   | TC2–TC6 (all 8 data bits) |
| DATA → STOP        | TC2–TC6                   |
| STOP → IDLE        | TC2–TC6                   |
| Any → IDLE (reset) | TC17, TC18, TC19          |

### RX FSM
| Transition              | TCs Covering              |
|-------------------------|---------------------------|
| IDLE → IDLE             | Line idle periods         |
| IDLE → START            | TC8–TC12, TC16, TC22      |
| START → IDLE (false st) | TC13                      |
| START → DATAOUT         | TC8–TC12                  |
| DATAOUT → DATAOUT (×7)  | TC8–TC12 (all 8 bits)     |
| DATAOUT → STOP          | TC8–TC12                  |
| STOP → IDLE (valid)     | TC8–TC12                  |
| STOP → IDLE (bad stop)  | TC14                      |
| Any → IDLE (reset)      | TC20                      |
