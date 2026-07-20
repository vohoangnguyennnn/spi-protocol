//
// tb_spi_slave.v - Simple self-checking testbench for spi_slave.
//
// The testbench acts as a Mode 0 SPI master. It sends one byte on MOSI and
// samples one byte from MISO, then checks both directions of the transfer.
//
`timescale 1ns / 1ps

module tb_spi_slave;

    localparam DATA_WIDTH = 8;
    localparam HALF_PERIOD = 10;

    reg rst_n;
    reg sclk;
    reg cs_n;
    reg mosi;
    reg [DATA_WIDTH-1:0] tx_data;

    wire miso;
    wire miso_oe;
    wire [DATA_WIDTH-1:0] rx_data;
    wire rx_valid;
    wire busy;

    integer test_count;
    integer error_count;

    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(1'b0),
        .CPHA(1'b0)
    ) dut (
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .tx_data(tx_data),
        .miso(miso),
        .miso_oe(miso_oe),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .busy(busy)
    );

    // Perform one full-duplex Mode 0 transfer.
    task spi_transfer;
        input [DATA_WIDTH-1:0] master_tx;
        input [DATA_WIDTH-1:0] slave_tx;
        output [DATA_WIDTH-1:0] master_rx;
        integer bit_index;
        begin
            tx_data = slave_tx;
            master_rx = {DATA_WIDTH{1'b0}};
            mosi = master_tx[DATA_WIDTH-1];
            cs_n = 1'b0;

            #1;
            if ((busy !== 1'b1) || (miso_oe !== 1'b1)) begin
                $display("FAIL: busy/miso_oe not asserted with cs_n low");
                error_count = error_count + 1;
            end

            #(HALF_PERIOD-1);
            for (bit_index = DATA_WIDTH-1;
                 bit_index >= 0;
                 bit_index = bit_index - 1) begin
                // Mode 0 samples data on the rising edge.
                sclk = 1'b1;
                #1;
                master_rx[bit_index] = miso;
                #(HALF_PERIOD-1);

                // Data for the next bit changes after the falling edge.
                sclk = 1'b0;
                if (bit_index > 0)
                    mosi = master_tx[bit_index-1];
                #HALF_PERIOD;
            end

            cs_n = 1'b1;
            mosi = 1'b0;
            #1;
            if ((busy !== 1'b0) || (miso_oe !== 1'b0)) begin
                $display("FAIL: busy/miso_oe not released with cs_n high");
                error_count = error_count + 1;
            end
            #(HALF_PERIOD-1);
        end
    endtask

    task run_test;
        input [DATA_WIDTH-1:0] master_tx;
        input [DATA_WIDTH-1:0] slave_tx;
        reg [DATA_WIDTH-1:0] master_rx;
        integer errors_before;
        begin
            test_count = test_count + 1;
            errors_before = error_count;

            spi_transfer(master_tx, slave_tx, master_rx);

            if (rx_data !== master_tx) begin
                $display("FAIL [%0d]: slave RX expected %02h, got %02h", test_count, master_tx, rx_data);
                error_count = error_count + 1;
            end

            if (master_rx !== slave_tx) begin
                $display("FAIL [%0d]: master RX expected %02h, got %02h", test_count, slave_tx, master_rx);
                error_count = error_count + 1;
            end

            if (rx_valid !== 1'b1) begin
                $display("FAIL [%0d]: rx_valid was not asserted", test_count);
                error_count = error_count + 1;
            end

            if (error_count == errors_before)
                $display("PASS [%0d]: MOSI=%02h, MISO=%02h", test_count, master_tx, slave_tx);
        end
    endtask

    initial begin
        $dumpfile("tb_spi_slave.vcd");
        $dumpvars(0, tb_spi_slave);

        rst_n = 1'b0;
        sclk = 1'b0;
        cs_n = 1'b1;
        mosi = 1'b0;
        tx_data = {DATA_WIDTH{1'b0}};
        test_count = 0;
        error_count = 0;

        #40;
        rst_n = 1'b1;
        #20;

        $display("=== Testing spi_slave (Mode 0) ===");
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
