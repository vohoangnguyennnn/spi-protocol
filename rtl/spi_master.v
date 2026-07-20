//
// spi_master.v - Single-word SPI master, modes 0..3, MSB-first.
//
// Pulse start for one clk cycle while idle. The core latches tx_data, transfers
// DATA_WIDTH bits in both directions, then pulses done when rx_data is ready.
// CLK_DIV sets the SCLK half-period: f_sclk = f_clk / (2 * CLK_DIV).
// CPHA=0 samples on leading edges; CPHA=1 samples on trailing edges.
// CS returns high after each word. DATA_WIDTH and CLK_DIV must be at least 1.
//
// Verilog-2001.
//
`timescale 1ns / 1ps

module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CLK_DIV = 2,
    parameter CPOL = 1'b0,
    parameter CPHA = 1'b0
)(
    input  wire clk,       // system clock
    input  wire rst_n,     // asynchronous active-low reset
    input  wire start,     // one-cycle pulse; accepted when idle
    input  wire [DATA_WIDTH-1:0] tx_data,   // word sent on MOSI
    input  wire miso,      // master in, slave out

    output reg sclk,      // generated SPI clock
    output reg cs_n,      // active-low chip select
    output reg mosi,      // master out, slave in
    output reg [DATA_WIDTH-1:0] rx_data,   // last completely received word
    output reg busy,      // high while a transfer is active
    output reg done       // one-clk pulse when rx_data is new
);

    // Counter-width
    function integer clog2;
        input integer value;
        integer count;
        begin
            value = value - 1;
            count = 0;
            while (value > 0) begin
                value = value >> 1;
                count = count + 1;
            end
            clog2 = (count == 0) ? 1 : count;
        end
    endfunction

    localparam BIT_CNT_WIDTH = clog2(DATA_WIDTH);
    localparam DIV_CNT_WIDTH = clog2(CLK_DIV);
    localparam [0:0] CPOL_VALUE = (CPOL != 0);
    localparam [0:0] CPHA_VALUE = (CPHA != 0);

    localparam [31:0] LAST_BIT_VALUE = DATA_WIDTH - 1;
    localparam [31:0] DIV_LIMIT_VALUE = CLK_DIV - 1;

    reg [DATA_WIDTH-1:0] tx_shift;
    reg [DATA_WIDTH-1:0] rx_shift;
    reg [BIT_CNT_WIDTH-1:0] bit_cnt;
    reg [DIV_CNT_WIDTH-1:0] div_cnt;

    // Values after shifting one bit.
    wire [DATA_WIDTH-1:0] sampled_word;
    wire [DATA_WIDTH-1:0] next_tx_word;
    assign sampled_word = (rx_shift << 1) |
                          {{(DATA_WIDTH-1){1'b0}}, miso};
    assign next_tx_word = tx_shift << 1;

    // CPHA=0 needs one final trailing edge after sampling the last bit.
    reg last_sampled;
    reg finish_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk <= CPOL_VALUE;
            cs_n <= 1'b1;
            mosi <= 1'b0;
            rx_data <= {DATA_WIDTH{1'b0}};
            busy <= 1'b0;
            done <= 1'b0;
            tx_shift <= {DATA_WIDTH{1'b0}};
            rx_shift <= {DATA_WIDTH{1'b0}};
            bit_cnt <= {BIT_CNT_WIDTH{1'b0}};
            div_cnt <= {DIV_CNT_WIDTH{1'b0}};
            last_sampled <= 1'b0;
            finish_pending <= 1'b0;
        end else begin
            // Default low makes done a one-clk pulse.
            done <= 1'b0;

            if (!busy) begin
                sclk <= CPOL_VALUE;
                cs_n <= 1'b1;
                mosi <= 1'b0;
                div_cnt <= {DIV_CNT_WIDTH{1'b0}};
                last_sampled <= 1'b0;
                finish_pending <= 1'b0;

                if (start) begin
                    busy <= 1'b1;
                    cs_n <= 1'b0;
                    tx_shift <= tx_data;
                    rx_shift <= {DATA_WIDTH{1'b0}};
                    bit_cnt <= {BIT_CNT_WIDTH{1'b0}};

                    // CPHA=0 requires the first MOSI bit before the first edge.
                    if (CPHA_VALUE == 1'b0)
                        mosi <= tx_data[DATA_WIDTH-1];
                end
            end else if (finish_pending) begin
                // Release CS after the final SCLK edge has settled.
                busy <= 1'b0;
                done <= 1'b1;
                cs_n <= 1'b1;
                mosi <= 1'b0;
                finish_pending <= 1'b0;
            end else if (div_cnt == DIV_LIMIT_VALUE[DIV_CNT_WIDTH-1:0]) begin
                div_cnt <= {DIV_CNT_WIDTH{1'b0}};

                if (sclk == CPOL_VALUE) begin
                    // Leading edge moves SCLK away from its CPOL idle level.
                    sclk <= ~sclk;

                    if (CPHA_VALUE == 1'b0) begin
                        // CPHA=0: sample MISO.
                        rx_shift <= sampled_word;

                        if (bit_cnt == LAST_BIT_VALUE[BIT_CNT_WIDTH-1:0])
                            last_sampled <= 1'b1;
                        else
                            bit_cnt <= bit_cnt + 1'b1;
                    end else begin
                        // CPHA=1: launch MOSI.
                        mosi <= tx_shift[DATA_WIDTH-1];
                    end
                end else begin
                    // Trailing edge returns SCLK to its CPOL idle level.
                    sclk <= CPOL_VALUE;

                    if (CPHA_VALUE == 1'b0) begin
                        if (last_sampled) begin
                            // Finish after returning SCLK to idle.
                            rx_data <= rx_shift;
                            mosi <= 1'b0;
                            last_sampled <= 1'b0;
                            finish_pending <= 1'b1;
                        end else begin
                            tx_shift <= next_tx_word;
                            mosi <= next_tx_word[DATA_WIDTH-1];
                        end
                    end else begin
                        // CPHA=1: sample MISO.
                        rx_shift <= sampled_word;

                        if (bit_cnt == LAST_BIT_VALUE[BIT_CNT_WIDTH-1:0]) begin
                            rx_data <= sampled_word;
                            finish_pending <= 1'b1;
                        end else begin
                            bit_cnt <= bit_cnt + 1'b1;
                            tx_shift <= next_tx_word;
                        end
                    end
                end
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end
    end

endmodule
