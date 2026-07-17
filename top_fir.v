`timescale 1ns / 1ps  

module top_fir(
    input clk,
    input rst,

    input uart_rx,
    output uart_tx,

    output [15:0] led
);

wire uart_busy;
wire uart_rdy;
wire [7:0] uart_rx_data;

wire ap_done;
wire ap_ready;
wire output_vld;
wire [31:0] fir_out;

reg [31:0] sample_reg;
reg ap_start;
reg pending_start;

//-----------------------------------------
// UART TX
//-----------------------------------------
reg uart_wr_en;
reg [7:0] uart_tx_data;

reg [7:0] tens_ascii;
reg [7:0] ones_ascii;

reg [3:0] tx_state;

localparam IDLE            = 4'd0;
localparam SEND_TENS       = 4'd1;
localparam WAIT_TENS_BUSY  = 4'd2;
localparam WAIT_TENS_DONE  = 4'd3;
localparam SEND_ONES       = 4'd4;
localparam WAIT_ONES_BUSY  = 4'd5;
localparam WAIT_ONES_DONE  = 4'd6;
localparam SEND_CR         = 4'd7;
localparam WAIT_CR_BUSY    = 4'd8;
localparam WAIT_CR_DONE    = 4'd9;
localparam SEND_LF         = 4'd10;
localparam WAIT_LF_BUSY    = 4'd11;
localparam WAIT_LF_DONE    = 4'd12;



//-----------------------------------------
// FIR output latch
//-----------------------------------------
reg [31:0] latched_out;

always @(posedge clk)
begin
    if(rst)
        latched_out <= 32'd0;
    else if(output_vld)
        latched_out <= fir_out;
end

//-----------------------------------------
// output_vld edge detector
//-----------------------------------------
reg output_vld_d;

always @(posedge clk)
begin
    if(rst)
        output_vld_d <= 1'b0;
    else
        output_vld_d <= output_vld;
end

wire output_vld_pulse;
assign output_vld_pulse = output_vld & ~output_vld_d;

//-----------------------------------------
// UART TX LOGIC
//-----------------------------------------
always @(posedge clk)
begin
    if(rst)
    begin
        uart_wr_en   <= 1'b0;
        uart_tx_data <= 8'd0;

        tx_state     <= IDLE;

        tens_ascii   <= 8'd0;
        ones_ascii   <= 8'd0;
    end
    else
    begin
        uart_wr_en <= 1'b0;

        case(tx_state)

        //---------------------------------
        // Wait for FIR result
        //---------------------------------
        IDLE:
        begin
            if(output_vld_pulse)
            begin
                tens_ascii <= (fir_out / 10) + 8'd48;
                ones_ascii <= (fir_out % 10) + 8'd48;

                tx_state <= SEND_TENS;
            end
        end

 
        //---------------------------------
        // Tens digit
        //---------------------------------
        SEND_TENS:
        begin
            uart_tx_data <= tens_ascii;
            uart_wr_en   <= 1'b1;
            tx_state     <= WAIT_TENS_BUSY;
        end

        WAIT_TENS_BUSY:
        begin
            if(uart_busy)
                tx_state <= WAIT_TENS_DONE;
        end

        WAIT_TENS_DONE:
        begin
            if(!uart_busy)
                tx_state <= SEND_ONES;
        end

        //---------------------------------
        // Ones digit
        //---------------------------------
        SEND_ONES:
        begin
            uart_tx_data <= ones_ascii;
            uart_wr_en   <= 1'b1;
            tx_state     <= WAIT_ONES_BUSY;
        end

        WAIT_ONES_BUSY:
        begin
            if(uart_busy)
                tx_state <= WAIT_ONES_DONE;
        end

        WAIT_ONES_DONE:
        begin
            if(!uart_busy)
                tx_state <= SEND_CR;
        end

        //---------------------------------
        // CR
        //---------------------------------
        SEND_CR:
        begin
            uart_tx_data <= 8'h0D;
            uart_wr_en   <= 1'b1;
            tx_state     <= WAIT_CR_BUSY;
        end

        WAIT_CR_BUSY:
        begin
            if(uart_busy)
                tx_state <= WAIT_CR_DONE;
        end

        WAIT_CR_DONE:
        begin
            if(!uart_busy)
                tx_state <= SEND_LF;
        end

        //---------------------------------
        // LF
        //---------------------------------
        SEND_LF:
        begin
            uart_tx_data <= 8'h0A;
            uart_wr_en   <= 1'b1;
            tx_state     <= WAIT_LF_BUSY;
        end

        WAIT_LF_BUSY:
        begin
            if(uart_busy)
                tx_state <= WAIT_LF_DONE;
        end

        WAIT_LF_DONE:
        begin
            if(!uart_busy)
                tx_state <= IDLE;
        end

        default:
            tx_state <= IDLE;

        endcase
    end
end

//-----------------------------------------
// UART RDY edge detector
//-----------------------------------------
reg uart_rdy_d;

always @(posedge clk)
begin
    if(rst)
        uart_rdy_d <= 1'b0;
    else
        uart_rdy_d <= uart_rdy;
end

wire uart_rdy_pulse;
assign uart_rdy_pulse = uart_rdy & ~uart_rdy_d;

//-----------------------------------------
// UART RX -> FIR
//-----------------------------------------
always @(posedge clk)
begin
    if(rst)
    begin
        sample_reg    <= 32'd0;
        ap_start      <= 1'b0;
        pending_start <= 1'b0;
    end
    else
    begin
        ap_start <= 1'b0;

        if(uart_rdy_pulse)
        begin
            sample_reg    <= uart_rx_data - 8'd48;
            pending_start <= 1'b1;
        end

        if(pending_start)
        begin
            ap_start      <= 1'b1;
            pending_start <= 1'b0;
        end
    end
end

//-----------------------------------------
// UART
//-----------------------------------------
uart_protocol UART0
(
    .clk(clk),
    .rst(rst),

    .uart_rx(uart_rx),
    .uart_tx(uart_tx),

    .wr_en(uart_wr_en),
    .rdy_clr(ap_start),

    .data_in(uart_tx_data),

    .busy(uart_busy),
    .rdy(uart_rdy),
    .data_out(uart_rx_data)
);

//-----------------------------------------
// FIR
//-----------------------------------------
filter_bd_wrapper DUT
(
    .ap_clk_0(clk),
    .ap_rst_0(rst),

    .ap_start_0(ap_start),

    .ap_done_0(ap_done),
    .ap_ready_0(ap_ready),

    .input_r_0(sample_reg),

    .output_r_0(fir_out),
    .output_r_ap_vld_0(output_vld),

    .rst_r_0(rst)
);

//-----------------------------------------
// LEDs
//-----------------------------------------
assign led[7:0]  = latched_out[7:0];

assign led[8]  = uart_rdy;
assign led[9]  = ap_start;
assign led[10] = ap_ready;
assign led[11] = output_vld;
assign led[12] = ap_done;

assign led[15:13] = 3'b000;

endmodule