//
// tb_spi_slave.v - self-checking testbench for spi_slave (Mode 0).
//
// The testbench acts as the SPI master: SCLK idles low, MOSI changes while
// SCLK is low, and MISO is sampled on the rising edge. Every vector checks
// both directions - what the slave received vs. what was sent on MOSI, and
// what the master shifted back vs. the slave's tx_data.
//
//   iverilog -o spi_slave_tb tb/tb_spi_slave.v rtl/spi_slave.v
//   vvp spi_slave_tb
//   gtkwave spi_slave.vcd
//
`timescale 1ns / 1ps

module tb_spi_slave;

    localparam DATA_WIDTH = 8;
    localparam HALF       = 10;          // half SCLK period in ns

    reg                    rst_n;
    reg                    sclk;
    reg                    cs_n;
    reg                    mosi;
    wire                   miso;
    reg  [DATA_WIDTH-1:0]  tx_data;
    wire [DATA_WIDTH-1:0]  rx_data;
    wire                   rx_valid;
    wire                   busy;

    integer error_count = 0;
    integer test_count  = 0;

    spi_slave #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .rst_n    (rst_n),
        .sclk     (sclk),
        .cs_n     (cs_n),
        .mosi     (mosi),
        .miso     (miso),
        .tx_data  (tx_data),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .busy     (busy)
    );

    // Drive one byte from the master side and capture what comes back on MISO.
    //   master_tx : byte clocked out on MOSI
    //   slave_tx  : byte the slave should return (loaded into tx_data)
    //   captured  : byte shifted in from MISO (expected to equal slave_tx)
    task spi_xfer(input [DATA_WIDTH-1:0] master_tx,
                  input [DATA_WIDTH-1:0] slave_tx,
                  output [DATA_WIDTH-1:0] captured);
        integer i;
        begin
            tx_data  = slave_tx;
            captured = {DATA_WIDTH{1'b0}};

            cs_n = 1'b0;                  // assert CS -> slave latches tx_data
            #HALF;                        // let the MSB settle on MISO

            for (i = DATA_WIDTH-1; i >= 0; i = i - 1) begin
                mosi = master_tx[i];      // set MOSI while SCLK is low
                #HALF;
                sclk = 1'b1;              // rising edge: slave samples MOSI
                captured[i] = miso;       // master samples MISO
                #HALF;
                sclk = 1'b0;              // falling edge: slave updates MISO
            end

            #HALF;
            cs_n = 1'b1;                  // release CS
            #(2*HALF);
        end
    endtask

    // Run one vector and check both directions.
    task run_vector(input [DATA_WIDTH-1:0] master_tx,
                    input [DATA_WIDTH-1:0] slave_tx);
        reg [DATA_WIDTH-1:0] captured;
        begin
            test_count = test_count + 1;
            spi_xfer(master_tx, slave_tx, captured);

            // master -> slave
            if (rx_data !== master_tx) begin
                $display("FAIL [%0d] rx_data : expected 0x%02h, got 0x%02h",
                         test_count, master_tx, rx_data);
                error_count = error_count + 1;
            end else if (rx_valid !== 1'b1) begin
                $display("FAIL [%0d] rx_valid not asserted after byte 0x%02h",
                         test_count, master_tx);
                error_count = error_count + 1;
            end else begin
                $display("PASS [%0d] MOSI->slave  : rx_data = 0x%02h",
                         test_count, rx_data);
            end

            // slave -> master
            if (captured !== slave_tx) begin
                $display("FAIL [%0d] MISO        : expected 0x%02h, got 0x%02h",
                         test_count, slave_tx, captured);
                error_count = error_count + 1;
            end else begin
                $display("PASS [%0d] slave->MOSI  : miso    = 0x%02h",
                         test_count, captured);
            end
        end
    endtask

    initial begin
        $dumpfile("spi_slave.vcd");
        $dumpvars(0, tb_spi_slave);

        // Idle state: SCLK low, CS high (Mode 0).
        rst_n   = 1'b0;
        sclk    = 1'b0;
        cs_n    = 1'b1;
        mosi    = 1'b0;
        tx_data = {DATA_WIDTH{1'b0}};
        #(4*HALF);
        rst_n   = 1'b1;
        #(4*HALF);

        $display("=== SPI Slave (Mode 0) self-checking testbench ===");

        // Required bytes, each paired with a slave response.
        run_vector(8'hA5, 8'h5A);
        run_vector(8'h3C, 8'hC3);
        run_vector(8'hFF, 8'h00);
        run_vector(8'h00, 8'hFF);

        // A couple of extra patterns.
        run_vector(8'h81, 8'h7E);
        run_vector(8'h12, 8'h34);

        #(4*HALF);
        $display("==================================================");
        if (error_count == 0)
            $display("RESULT: ALL %0d TESTS PASSED", test_count);
        else
            $display("RESULT: %0d ERROR(S) IN %0d TESTS", error_count, test_count);
        $display("==================================================");

        $finish;
    end

    // Keep the run from hanging if something goes wrong.
    initial begin
        #100000;
        $display("FAIL: simulation timeout");
        $finish;
    end

endmodule
