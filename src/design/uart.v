// ============================================================
// uart.v  –  8-bit UART, 2400 baud @ 50 MHz
// Parameters:
//   b  – data bits (default 8)
// ============================================================
// Place your RTL implementation here.
// Expected ports:
//   input            sys_rst_l       – active-low async reset
//   input            sys_clk         – 50 MHz system clock
//   input            xmitH           – transmit strobe
//   input  [b-1:0]   data_in         – parallel TX data
//   input            uart_REC_dataH  – serial RX input
//   output           uart_XMIT_dataH – serial TX output
//   output           xmit_doneH      – TX complete flag
//   output [b-1:0]   rec_dataH       – parallel RX data
//   output           xmit_active     – TX FSM busy
//   output           rec_busy        – RX FSM busy
//   output           rec_readyH      – RX data valid
