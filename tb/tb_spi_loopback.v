//
// tb_spi_loopback.v - Integration test for spi_master and spi_slave.
//
// Both RTL blocks are connected through the SPI bus. CPOL and CPHA are top
// parameters so the same testbench can verify all four standard SPI modes.
// Each transaction checks both directions of the full-duplex transfer.
//
`timescale 1ns / 1ps

module tb_spi_loopback #(
    parameter CPOL = 1'b0,
    parameter CPHA = 1'b0
);

    localparam DATA_WIDTH = 8;
    localparam CLK_DIV = 2;
    localparam CLK_PERIOD = 10;
    localparam SPI_MODE = (CPOL * 2) + CPHA;

    reg clk;
    reg rst_n;
    reg start;
    reg [DATA_WIDTH-1:0] master_tx_data;
    reg [DATA_WIDTH-1:0] slave_tx_data;

    wire sclk;
    wire cs_n;
    wire mosi;
    wire miso;
    wire miso_oe;

    wire [DATA_WIDTH-1:0] master_rx_data;
    wire master_busy;
    wire master_done;

    wire [DATA_WIDTH-1:0] slave_rx_data;
    wire slave_rx_valid;
    wire slave_busy;

    integer test_count;
    integer error_count;

    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) master_dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(master_tx_data),
        .miso(miso),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .rx_data(master_rx_data),
        .busy(master_busy),
        .done(master_done)
    );

    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) slave_dut (
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .tx_data(slave_tx_data),
        .miso(miso),
        .miso_oe(miso_oe),
        .rx_data(slave_rx_data),
        .rx_valid(slave_rx_valid),
        .busy(slave_busy)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    task run_test;
        input [DATA_WIDTH-1:0] master_tx;
        input [DATA_WIDTH-1:0] slave_tx;
        integer errors_before;
        begin
            test_count = test_count + 1;
            errors_before = error_count;
            master_tx_data = master_tx;
            slave_tx_data = slave_tx;

            // Pulse start for one system-clock cycle.
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            if ((master_busy !== 1'b1) || (slave_busy !== 1'b1) ||
                (cs_n !== 1'b0) || (miso_oe !== 1'b1)) begin
                $display("FAIL [%0d]: loopback transfer did not become active",
                         test_count);
                error_count = error_count + 1;
            end

            wait (master_done === 1'b1);
            #1;

            if (master_rx_data !== slave_tx) begin
                $display("FAIL [%0d]: master RX expected %02h, got %02h",
                         test_count, slave_tx, master_rx_data);
                error_count = error_count + 1;
            end

            if (slave_rx_data !== master_tx) begin
                $display("FAIL [%0d]: slave RX expected %02h, got %02h",
                         test_count, master_tx, slave_rx_data);
                error_count = error_count + 1;
            end

            if (slave_rx_valid !== 1'b1) begin
                $display("FAIL [%0d]: slave rx_valid was not asserted",
                         test_count);
                error_count = error_count + 1;
            end

            if ((master_busy !== 1'b0) || (slave_busy !== 1'b0) ||
                (cs_n !== 1'b1) || (sclk !== CPOL) ||
                (miso_oe !== 1'b0)) begin
                $display("FAIL [%0d]: SPI bus did not return to idle",
                         test_count);
                error_count = error_count + 1;
            end

            // master_done must be a one-system-clock pulse.
            @(posedge clk);
            #1;
            if (master_done !== 1'b0) begin
                $display("FAIL [%0d]: master_done is wider than one clock",
                         test_count);
                error_count = error_count + 1;
            end

            if (error_count == errors_before)
                $display("PASS [%0d]: master TX=%02h, slave TX=%02h",
                         test_count, master_tx, slave_tx);
        end
    endtask

    initial begin
        $dumpfile("tb_spi_loopback.vcd");
        $dumpvars(0, tb_spi_loopback);

        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        master_tx_data = {DATA_WIDTH{1'b0}};
        slave_tx_data = {DATA_WIDTH{1'b0}};
        test_count = 0;
        error_count = 0;

        #40;
        rst_n = 1'b1;
        #20;

        $display("=== Testing SPI master/slave loopback (Mode %0d) ===",
                 SPI_MODE);
        run_test(8'hA5, 8'h5A);
        run_test(8'h3C, 8'hC3);
        run_test(8'h00, 8'hFF);
        run_test(8'hFF, 8'h00);

        if (error_count == 0)
            $display("RESULT: PASS (%0d/%0d tests)", test_count, test_count);
        else
            $display("RESULT: FAIL (%0d error(s))", error_count);

        $finish;
    end

    initial begin
        #100000;
        $display("RESULT: FAIL (simulation timeout)");
        $finish;
    end

endmodule
