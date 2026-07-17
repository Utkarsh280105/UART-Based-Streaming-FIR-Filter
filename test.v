`timescale 1ns/1ps

module tb_top_fir;

reg clk;
reg rst;

reg uart_rx;
wire uart_tx;

wire [15:0] led;

localparam integer BIT_PERIOD = 8680;

top_fir DUT
(
    .clk(clk),
    .rst(rst),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),
    .led(led)
);

always #5 clk = ~clk;

////////////////////////////////////////////////////
// UART TRANSMIT TASK
////////////////////////////////////////////////////

task uart_send_byte;
input [7:0] data;
integer i;
begin

    uart_rx = 1'b0;
    #(BIT_PERIOD);

    for(i=0;i<8;i=i+1)
    begin
        uart_rx = data[i];
        #(BIT_PERIOD);
    end

    uart_rx = 1'b1;
    #(BIT_PERIOD);

end
endtask

////////////////////////////////////////////////////
// MONITOR FIR OUTPUT
////////////////////////////////////////////////////

always @(posedge clk)
begin
    if(DUT.output_vld)
    begin
        $display(
        "[FIR] TIME=%0t INPUT=%0d OUTPUT=%0d",
        $time,
        DUT.sample_reg,
        DUT.fir_out
        );
    end
end

////////////////////////////////////////////////////
// MONITOR UART RX
////////////////////////////////////////////////////

always @(posedge clk)
begin
    if(DUT.uart_rdy)
    begin
        $display(
        "[UART RX] TIME=%0t DATA=%0d (0x%h)",
        $time,
        DUT.uart_rx_data,
        DUT.uart_rx_data
        );
    end
end

////////////////////////////////////////////////////
// MONITOR UART TX
////////////////////////////////////////////////////

always @(posedge clk)
begin
    if(DUT.uart_wr_en)
    begin
        $display(
        "[UART TX] TIME=%0t DATA=%c (0x%h)",
        $time,
        DUT.uart_tx_data,
        DUT.uart_tx_data
        );
    end
end

////////////////////////////////////////////////////
// GENERAL MONITOR
////////////////////////////////////////////////////

initial
begin
    $monitor(
    "T=%0t rst=%b led=%0d uart_busy=%b uart_rdy=%b",
    $time,
    rst,
    led,
    DUT.uart_busy,
    DUT.uart_rdy
    );
end

////////////////////////////////////////////////////
// TEST SEQUENCE
////////////////////////////////////////////////////

initial
begin

    clk     = 0;
    rst     = 1;
    uart_rx = 1'b1;

    #100;

    rst = 0;

    #100000;

    $display("\n====================================");
    $display("SENDING 8 SAMPLES OF VALUE 1");
    $display("====================================");

    uart_send_byte("1");
    #20000;

    uart_send_byte("2");
    #20000;

    uart_send_byte("1");
    #20000;

    uart_send_byte("2");
    #20000;

    uart_send_byte("1");
    #20000;

    uart_send_byte("2");
    #20000;

    uart_send_byte("1");
    #20000;

    uart_send_byte("2");
    #20000;

    #5000000;

    $display("\n====================================");
    $display("SIMULATION COMPLETE");
    $display("====================================");

    $finish;

end

endmodule