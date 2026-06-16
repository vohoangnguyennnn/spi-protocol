//
// spi_slave.v - SPI slave, Mode 0 (CPOL=0, CPHA=0), MSB first.
//
// SCLK idles low. MOSI is sampled on the rising edge, MISO changes on the
// falling edge. Because CPHA=0, the first bit must be on MISO before the
// first rising edge, so tx_data is latched (and its MSB driven out) the
// moment CS goes active.
//
// Verilog-2001.
//
`timescale 1ns / 1ps

module spi_slave #(
    parameter DATA_WIDTH = 8
)(
    input  wire                   rst_n,     // async active-low reset
    input  wire                   sclk,      // SPI clock from master (idles low)
    input  wire                   cs_n,      // active-low chip select
    input  wire                   mosi,      // master out, slave in
    output reg                    miso,      // master in,  slave out
    input  wire [DATA_WIDTH-1:0]  tx_data,   // byte sent back to the master
    output reg  [DATA_WIDTH-1:0]  rx_data,   // last received byte
    output reg                    rx_valid,  // pulses high when rx_data is new
    output reg                    busy       // high while a transfer is running
);

    // Bit counter width: DATA_WIDTH=8 -> 3 bits (0..7).
    localparam CNT_WIDTH = (DATA_WIDTH <= 2)  ? 1 :
                           (DATA_WIDTH <= 4)  ? 2 :
                           (DATA_WIDTH <= 8)  ? 3 :
                           (DATA_WIDTH <= 16) ? 4 :
                           (DATA_WIDTH <= 32) ? 5 : 6;

    //  Receive: shift MOSI in on the rising edge, MSB first
    reg [DATA_WIDTH-1:0] rx_shift;
    reg [CNT_WIDTH-1:0]  bit_cnt;

    always @(posedge sclk or negedge rst_n or posedge cs_n) begin
        if (!rst_n) begin
            rx_shift <= {DATA_WIDTH{1'b0}};
            bit_cnt  <= {CNT_WIDTH{1'b0}};
            rx_data  <= {DATA_WIDTH{1'b0}};
            rx_valid <= 1'b0;
        end else if (cs_n) begin
            // Idle between transactions; keep rx_data/rx_valid for the reader.
            rx_shift <= {DATA_WIDTH{1'b0}};
            bit_cnt  <= {CNT_WIDTH{1'b0}};
        end else begin
            rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};
            if (bit_cnt == DATA_WIDTH-1) begin
                rx_data  <= {rx_shift[DATA_WIDTH-2:0], mosi};   // byte complete
                rx_valid <= 1'b1;
                bit_cnt  <= {CNT_WIDTH{1'b0}};
            end else begin
                rx_valid <= 1'b0;
                bit_cnt  <= bit_cnt + 1'b1;
            end
        end
    end

    //  Transmit: drive MISO MSB first, advancing on the falling edge
    reg [DATA_WIDTH-1:0] tx_hold;
    reg [CNT_WIDTH:0]    tx_idx;

    // Latch the byte to send when CS asserts.
    always @(negedge cs_n or negedge rst_n) begin
        if (!rst_n)
            tx_hold <= {DATA_WIDTH{1'b0}};
        else
            tx_hold <= tx_data;
    end

    // Bit index, reset between transactions by CS going high.
    always @(negedge sclk or negedge rst_n or posedge cs_n) begin
        if (!rst_n)
            tx_idx <= {(CNT_WIDTH+1){1'b0}};
        else if (cs_n)
            tx_idx <= {(CNT_WIDTH+1){1'b0}};
        else
            tx_idx <= tx_idx + 1'b1;
    end

    // MSB at CS assertion, next bit on each falling edge; low when idle.
    always @(*) begin
        if (cs_n || (tx_idx >= DATA_WIDTH))
            miso = 1'b0;
        else
            miso = tx_hold[DATA_WIDTH-1 - tx_idx];
    end

    always @(*) begin
        busy = ~cs_n;
    end

endmodule
