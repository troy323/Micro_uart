`timescale 1ns/1ps

module uart_tb;

parameter b = 8;
parameter CLK_PERIOD = 20; // 50 MHz -> 20 ns

// DUT signals
reg          sys_rst_l, sys_clk, xmitH;
reg  [b-1:0] data_in;
reg          uart_REC_dataH;
wire         uart_XMIT_dataH;
wire         xmit_doneH;
wire [b-1:0] rec_dataH;
wire         xmit_active, rec_busy, rec_readyH;

// -----------------------------------------------------------------------
// Timing constants
// baud_rate: clk_value = 50_000_000 / (2400 * 16 * 2) = 651 sys_clks
// clk_enable fires every 651 sys_clks
// 1 UART bit  = 16 clk_enables = 16 * 651 = 10416 sys_clks
// -----------------------------------------------------------------------
parameter CLK_VALUE     = 651;
parameter BIT_CLKS      = 16 * CLK_VALUE;  // 10416 sys_clks per bit
parameter HALF_BIT_CLKS =  8 * CLK_VALUE;  //  5208 sys_clks

// Expose internal clk_enable for synchronisation
wire clk_enable = dut.clk_enable;

// Instantiate DUT
uart #(b) dut (
    .sys_rst_l       (sys_rst_l),
    .sys_clk         (sys_clk),
    .xmitH           (xmitH),
    .data_in         (data_in),
    .uart_REC_dataH  (uart_REC_dataH),
    .uart_XMIT_dataH (uart_XMIT_dataH),
    .xmit_doneH      (xmit_doneH),
    .rec_dataH       (rec_dataH),
    .xmit_active     (xmit_active),
    .rec_busy        (rec_busy),
    .rec_readyH      (rec_readyH)
);

// Clock
initial sys_clk = 0;
always #(CLK_PERIOD/2) sys_clk = ~sys_clk;

// -----------------------------------------------------------------------
// Helper: wait for next rising clk_enable pulse
// -----------------------------------------------------------------------
task wait_clk_enable;
begin
    @(posedge sys_clk);
    while (!clk_enable) @(posedge sys_clk);
end
endtask

// -----------------------------------------------------------------------
// Task: reset
// -----------------------------------------------------------------------
task do_reset;
begin
    sys_rst_l      = 0;
    xmitH          = 0;
    data_in        = 0;
    uart_REC_dataH = 1;
    repeat(4) @(posedge sys_clk);
    sys_rst_l = 1;
    @(posedge sys_clk);
end
endtask

// -----------------------------------------------------------------------
// Task: transmit one byte
// -----------------------------------------------------------------------
task uart_transmit;
    input [b-1:0] byte_val;
    integer timeout;
begin
    data_in = byte_val;
    xmitH   = 1;
    wait_clk_enable;
    @(posedge sys_clk);
    xmitH = 0;
    timeout = 0;
    while (xmit_doneH !== 1 && timeout < 2000000) begin
        @(posedge sys_clk);
        timeout = timeout + 1;
    end
    if (timeout >= 2000000)
        $display("TIMEOUT TX: byte=0x%0h", byte_val);
    else
        $display("TX PASS: sent=0x%0h", byte_val);
end
endtask

// -----------------------------------------------------------------------
// Task: receive one byte
// -----------------------------------------------------------------------
task uart_receive;
    input [b-1:0] byte_val;
    integer i, timeout;
begin
    uart_REC_dataH = 0;
    repeat(BIT_CLKS) @(posedge sys_clk);
    for (i = 0; i < b; i = i + 1) begin
        uart_REC_dataH = byte_val[i];
        repeat(BIT_CLKS) @(posedge sys_clk);
    end
    uart_REC_dataH = 1;
    repeat(BIT_CLKS) @(posedge sys_clk);
    timeout = 0;
    while (rec_readyH !== 1 && timeout < 500000) begin
        @(posedge sys_clk);
        timeout = timeout + 1;
    end
    if (timeout >= 500000)
        $display("TIMEOUT RX: byte=0x%0h", byte_val);
    else if (rec_dataH === byte_val)
        $display("RX PASS: expected=0x%0h got=0x%0h", byte_val, rec_dataH);
    else
        $display("RX FAIL: expected=0x%0h got=0x%0h", byte_val, rec_dataH);
end
endtask

// -----------------------------------------------------------------------
// Task: false start
// -----------------------------------------------------------------------
task uart_false_start;
begin
    uart_REC_dataH = 0;
    repeat(4 * CLK_VALUE) @(posedge sys_clk);
    uart_REC_dataH = 1;
    repeat(BIT_CLKS * 2) @(posedge sys_clk);
    $display("FALSE START: rec_busy=%0b rec_readyH=%0b (expect 0,1)",
             rec_busy, rec_readyH);
end
endtask

// -----------------------------------------------------------------------
// Task: receive with bad stop bit
// -----------------------------------------------------------------------
task uart_receive_bad_stop;
    input [b-1:0] byte_val;
    integer i;
begin
    uart_REC_dataH = 0;
    repeat(BIT_CLKS) @(posedge sys_clk);
    for (i = 0; i < b; i = i + 1) begin
        uart_REC_dataH = byte_val[i];
        repeat(BIT_CLKS) @(posedge sys_clk);
    end
    uart_REC_dataH = 0;
    repeat(BIT_CLKS) @(posedge sys_clk);
    uart_REC_dataH = 1;
    repeat(BIT_CLKS) @(posedge sys_clk);
    $display("BAD STOP: rec_readyH=%0b rec_busy=%0b (data not latched)",
             rec_readyH, rec_busy);
end
endtask

// -----------------------------------------------------------------------
// Test execution
// -----------------------------------------------------------------------
initial begin
    $dumpfile("uart_tb.vcd");
    $dumpvars(0, uart_tb);
    $display("=== UART Testbench Start ===");
    do_reset;

    $display("\n--- TC1: Reset state ---");
    if (xmit_doneH===1 && xmit_active===0 && rec_readyH===1 && rec_busy===0)
        $display("PASS: reset state correct");
    else
        $display("FAIL: xmit_doneH=%0b xmit_active=%0b rec_readyH=%0b rec_busy=%0b",
                 xmit_doneH, xmit_active, rec_readyH, rec_busy);

    $display("\n--- TC2:  TX 0x55 ---"); uart_transmit(8'h55);
    $display("\n--- TC3:  TX 0xAA ---"); uart_transmit(8'hAA);
    $display("\n--- TC4:  TX 0x00 ---"); uart_transmit(8'h00);
    $display("\n--- TC5:  TX 0xFF ---"); uart_transmit(8'hFF);
    $display("\n--- TC6:  TX 0xA5 ---"); uart_transmit(8'hA5);

    $display("\n--- TC7:  TX idle no-op ---");
    repeat(BIT_CLKS) @(posedge sys_clk);
    if (xmit_active===0 && xmit_doneH===1) $display("PASS: stayed IDLE");
    else $display("FAIL: unexpected activity");

    $display("\n--- TC8:  RX 0x55 ---"); uart_receive(8'h55);
    $display("\n--- TC9:  RX 0xAA ---"); uart_receive(8'hAA);
    $display("\n--- TC10: RX 0x00 ---"); uart_receive(8'h00);
    $display("\n--- TC11: RX 0xFF ---"); uart_receive(8'hFF);
    $display("\n--- TC12: RX 0xA5 ---"); uart_receive(8'hA5);

    $display("\n--- TC13: False start ---"); uart_false_start;
    $display("\n--- TC14: Bad stop bit ---"); uart_receive_bad_stop(8'hBB);

    $display("\n--- TC15: Back-to-back TX 0x12, 0x34 ---");
    uart_transmit(8'h12); uart_transmit(8'h34);

    $display("\n--- TC16: Back-to-back RX 0xBE, 0xEF ---");
    uart_receive(8'hBE); uart_receive(8'hEF);

    $display("\n--- TC17: Reset during TX START ---");
    data_in = 8'h7E; xmitH = 1;
    wait_clk_enable; @(posedge sys_clk); xmitH = 0;
    repeat(CLK_VALUE * 4) @(posedge sys_clk);
    sys_rst_l = 0; repeat(4) @(posedge sys_clk); sys_rst_l = 1;
    @(posedge sys_clk);
    if (xmit_active===0 && xmit_doneH===1) $display("PASS: reset in START ok");
    else $display("FAIL: xmit_active=%0b xmit_doneH=%0b", xmit_active, xmit_doneH);

    $display("\n--- TC18: Reset during TX DATA ---");
    data_in = 8'h7E; xmitH = 1;
    wait_clk_enable; @(posedge sys_clk); xmitH = 0;
    repeat(BIT_CLKS) @(posedge sys_clk); repeat(BIT_CLKS * 3) @(posedge sys_clk);
    sys_rst_l = 0; repeat(4) @(posedge sys_clk); sys_rst_l = 1;
    @(posedge sys_clk);
    if (xmit_active===0 && xmit_doneH===1) $display("PASS: reset in DATA ok");
    else $display("FAIL: xmit_active=%0b xmit_doneH=%0b", xmit_active, xmit_doneH);

    $display("\n--- TC19: Reset during TX STOP ---");
    data_in = 8'h55; xmitH = 1;
    wait_clk_enable; @(posedge sys_clk); xmitH = 0;
    repeat(BIT_CLKS * 10) @(posedge sys_clk);
    sys_rst_l = 0; repeat(4) @(posedge sys_clk); sys_rst_l = 1;
    @(posedge sys_clk);
    if (xmit_active===0 && xmit_doneH===1) $display("PASS: reset in STOP ok");
    else $display("FAIL: xmit_active=%0b xmit_doneH=%0b", xmit_active, xmit_doneH);

    $display("\n--- TC20: Reset during RX DATAOUT ---");
    uart_REC_dataH = 0; repeat(BIT_CLKS) @(posedge sys_clk);
    uart_REC_dataH = 1; repeat(BIT_CLKS * 3) @(posedge sys_clk);
    sys_rst_l = 0; repeat(4) @(posedge sys_clk); sys_rst_l = 1;
    uart_REC_dataH = 1; @(posedge sys_clk);
    if (rec_busy===0 && rec_readyH===1) $display("PASS: reset in RX DATA ok");
    else $display("FAIL: rec_busy=%0b rec_readyH=%0b", rec_busy, rec_readyH);

    $display("\n--- TC21: TX after reset 0xC3 ---"); uart_transmit(8'hC3);

    $display("\n--- TC22: RX after reset 0x3C ---");
    do_reset; uart_receive(8'h3C);

    $display("\n--- TC23: xmitH held long ---");
    data_in = 8'hDE; xmitH = 1;
    wait_clk_enable; @(posedge sys_clk);
    wait_clk_enable; @(posedge sys_clk);
    xmitH = 0;
    begin : blk_tc23
        integer t; t = 0;
        while (xmit_doneH !== 1 && t < 2000000) begin @(posedge sys_clk); t = t + 1; end
        if (xmit_doneH === 1) $display("TX PASS: single frame sent, done=%0b", xmit_doneH);
        else $display("TX TIMEOUT: held xmitH");
    end

    $display("\n=== UART Testbench Complete ===");
    $finish;
end

initial begin
    #(64'd500_000_000_000);
    $display("WATCHDOG TIMEOUT");
    $finish;
end

endmodule
