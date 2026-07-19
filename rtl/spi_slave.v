//
// spi_slave.v - Single-word SPI slave, modes 0..3, MSB-first.
//
// The core latches tx_data when CS goes low and receives DATA_WIDTH bits on
// MOSI. rx_valid is set when rx_data is complete and cleared on the first
// sample of the next transaction. CS must return high between words.
// CPHA=0 samples on leading edges; CPHA=1 samples on trailing edges.
// DATA_WIDTH must be at least 1.
//
// Verilog-2001.
//
`timescale 1ns / 1ps

module spi_slave #(
    parameter DATA_WIDTH = 8,
    parameter CPOL = 1'b0,
    parameter CPHA = 1'b0
)(
    input  wire rst_n,     // asynchronous active-low reset
    input  wire sclk,      // SPI clock from the master
    input  wire cs_n,      // active-low chip select
    input  wire mosi,      // master out, slave in
    input  wire [DATA_WIDTH-1:0] tx_data,   // word sent back to the master

    output reg miso,      // master in, slave out
    output wire miso_oe,   // high while this slave owns MISO
    output reg [DATA_WIDTH-1:0] rx_data,   // last completely received word
    output reg rx_valid,  // high when a new word was received
    output reg busy       // high while CS is active
);

    // Counter-width calculation
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
    localparam TX_CNT_WIDTH = clog2(DATA_WIDTH + 1);
    localparam [0:0] CPOL_VALUE = (CPOL != 0);
    localparam [0:0] CPHA_VALUE = (CPHA != 0);
    localparam [0:0] SAMPLE_ON_POSEDGE = (CPOL_VALUE == CPHA_VALUE);
    localparam [0:0] SHIFT_ON_POSEDGE = (CPOL_VALUE != CPHA_VALUE);
    localparam [31:0] LAST_BIT_VALUE = DATA_WIDTH - 1;
    localparam [31:0] DATA_WIDTH_VALUE = DATA_WIDTH;

    reg [DATA_WIDTH-1:0] rx_shift;
    reg [BIT_CNT_WIDTH-1:0] bit_cnt;
    reg rx_word_done;

    wire [DATA_WIDTH-1:0] sampled_word;
    assign sampled_word = (rx_shift << 1) |
                          {{(DATA_WIDTH-1){1'b0}}, mosi};

    // Select the receive edge at elaboration time.
    generate
        if (SAMPLE_ON_POSEDGE) begin : gen_rx_posedge
            always @(posedge sclk or negedge rst_n or posedge cs_n) begin
                if (!rst_n) begin
                    rx_shift     <= {DATA_WIDTH{1'b0}};
                    bit_cnt      <= {BIT_CNT_WIDTH{1'b0}};
                    rx_data      <= {DATA_WIDTH{1'b0}};
                    rx_valid     <= 1'b0;
                    rx_word_done <= 1'b0;
                end else if (cs_n) begin
                    rx_shift     <= {DATA_WIDTH{1'b0}};
                    bit_cnt      <= {BIT_CNT_WIDTH{1'b0}};
                    rx_word_done <= 1'b0;
                end else if (!rx_word_done) begin
                    rx_shift <= sampled_word;

                    if (bit_cnt == LAST_BIT_VALUE[BIT_CNT_WIDTH-1:0]) begin
                        rx_data      <= sampled_word;
                        rx_valid     <= 1'b1;
                        bit_cnt      <= {BIT_CNT_WIDTH{1'b0}};
                        rx_word_done <= 1'b1;
                    end else begin
                        rx_valid <= 1'b0;
                        bit_cnt  <= bit_cnt + 1'b1;
                    end
                end
            end
        end else begin : gen_rx_negedge
            always @(negedge sclk or negedge rst_n or posedge cs_n) begin
                if (!rst_n) begin
                    rx_shift     <= {DATA_WIDTH{1'b0}};
                    bit_cnt      <= {BIT_CNT_WIDTH{1'b0}};
                    rx_data      <= {DATA_WIDTH{1'b0}};
                    rx_valid     <= 1'b0;
                    rx_word_done <= 1'b0;
                end else if (cs_n) begin
                    rx_shift     <= {DATA_WIDTH{1'b0}};
                    bit_cnt      <= {BIT_CNT_WIDTH{1'b0}};
                    rx_word_done <= 1'b0;
                end else if (!rx_word_done) begin
                    rx_shift <= sampled_word;

                    if (bit_cnt == LAST_BIT_VALUE[BIT_CNT_WIDTH-1:0]) begin
                        rx_data      <= sampled_word;
                        rx_valid     <= 1'b1;
                        bit_cnt      <= {BIT_CNT_WIDTH{1'b0}};
                        rx_word_done <= 1'b1;
                    end else begin
                        rx_valid <= 1'b0;
                        bit_cnt  <= bit_cnt + 1'b1;
                    end
                end
            end
        end
    endgenerate

    // Capture the response before the first SPI edge.
    reg [DATA_WIDTH-1:0] tx_hold;
    always @(negedge cs_n or negedge rst_n) begin
        if (!rst_n)
            tx_hold <= {DATA_WIDTH{1'b0}};
        else
            tx_hold <= tx_data;
    end

    reg [TX_CNT_WIDTH-1:0] tx_idx;

    // CPHA=0 presents the first bit at CS assertion. CPHA=1 launches it on the
    // first leading edge, so the two phases use different output handling.
    generate
        if (CPHA_VALUE == 1'b0) begin : gen_tx_cpha0
            if (SHIFT_ON_POSEDGE) begin : gen_shift_posedge
                always @(posedge sclk or negedge rst_n or posedge cs_n) begin
                    if (!rst_n)
                        tx_idx <= {TX_CNT_WIDTH{1'b0}};
                    else if (cs_n)
                        tx_idx <= {TX_CNT_WIDTH{1'b0}};
                    else if (tx_idx < DATA_WIDTH_VALUE[TX_CNT_WIDTH-1:0])
                        tx_idx <= tx_idx + 1'b1;
                end
            end else begin : gen_shift_negedge
                always @(negedge sclk or negedge rst_n or posedge cs_n) begin
                    if (!rst_n)
                        tx_idx <= {TX_CNT_WIDTH{1'b0}};
                    else if (cs_n)
                        tx_idx <= {TX_CNT_WIDTH{1'b0}};
                    else if (tx_idx < DATA_WIDTH_VALUE[TX_CNT_WIDTH-1:0])
                        tx_idx <= tx_idx + 1'b1;
                end
            end

            always @(*) begin
                if (cs_n ||
                    (tx_idx >= DATA_WIDTH_VALUE[TX_CNT_WIDTH-1:0]))
                    miso = 1'b0;
                else
                    miso = tx_hold[
                        LAST_BIT_VALUE[BIT_CNT_WIDTH-1:0] -
                        tx_idx[BIT_CNT_WIDTH-1:0]
                    ];
            end
        end else begin : gen_tx_cpha1
            reg miso_shift;

            if (SHIFT_ON_POSEDGE) begin : gen_shift_posedge
                always @(posedge sclk or negedge rst_n or posedge cs_n) begin
                    if (!rst_n) begin
                        tx_idx     <= {TX_CNT_WIDTH{1'b0}};
                        miso_shift <= 1'b0;
                    end else if (cs_n) begin
                        tx_idx     <= {TX_CNT_WIDTH{1'b0}};
                        miso_shift <= 1'b0;
                    end else if (
                        tx_idx < DATA_WIDTH_VALUE[TX_CNT_WIDTH-1:0]
                    ) begin
                        miso_shift <= tx_hold[
                            LAST_BIT_VALUE[BIT_CNT_WIDTH-1:0] -
                            tx_idx[BIT_CNT_WIDTH-1:0]
                        ];
                        tx_idx     <= tx_idx + 1'b1;
                    end
                end
            end else begin : gen_shift_negedge
                always @(negedge sclk or negedge rst_n or posedge cs_n) begin
                    if (!rst_n) begin
                        tx_idx     <= {TX_CNT_WIDTH{1'b0}};
                        miso_shift <= 1'b0;
                    end else if (cs_n) begin
                        tx_idx     <= {TX_CNT_WIDTH{1'b0}};
                        miso_shift <= 1'b0;
                    end else if (
                        tx_idx < DATA_WIDTH_VALUE[TX_CNT_WIDTH-1:0]
                    ) begin
                        miso_shift <= tx_hold[
                            LAST_BIT_VALUE[BIT_CNT_WIDTH-1:0] -
                            tx_idx[BIT_CNT_WIDTH-1:0]
                        ];
                        tx_idx     <= tx_idx + 1'b1;
                    end
                end
            end

            always @(*) begin
                if (cs_n)
                    miso = 1'b0;
                else
                    miso = miso_shift;
            end
        end
    endgenerate

    assign miso_oe = ~cs_n;

    always @(*) begin
        busy = ~cs_n;
    end

endmodule
