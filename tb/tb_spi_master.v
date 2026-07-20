//
// tb_spi_master.v - Simple self-checking testbench for spi_master.
//
// The small slave model below returns a known byte on MISO and captures the
// byte sent by the DUT on MOSI. This keeps the test focused on the master RTL.
//
`timescale 1ns / 1ps

module tb_spi_master;

    localparam DATA_WIDTH = 8;
    localparam CLK_DIV = 2;
    localparam CLK_PERIOD = 10;

    reg clk;
    reg rst_n;
    reg start;
    reg [DATA_WIDTH-1:0] tx_data;
    reg miso;

    wire sclk;
    wire cs_n;
    wire mosi;
    wire [DATA_WIDTH-1:0] rx_data;
    wire busy;
    wire done;

    reg [DATA_WIDTH-1:0] slave_reply;
    reg [DATA_WIDTH-1:0] slave_tx_shift;
    reg [DATA_WIDTH-1:0] slave_rx_shift;

    integer test_count;
    integer error_count;

    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV),
        .CPOL(1'b0),
        .CPHA(1'b0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .miso(miso),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .rx_data(rx_data),
        .busy(busy),
        .done(done)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Minimal Mode 0 slave model. Load the first MISO bit when CS asserts.
    always @(negedge cs_n or negedge rst_n) begin
        if (!rst_n) begin
            slave_tx_shift = {DATA_WIDTH{1'b0}};
            slave_rx_shift = {DATA_WIDTH{1'b0}};
            miso = 1'b0;
        end else begin
            slave_tx_shift = slave_reply;
            slave_rx_shift = {DATA_WIDTH{1'b0}};
            miso = slave_reply[DATA_WIDTH-1];
        end
    end

    // The slave samples MOSI on each rising SCLK edge.
    always @(posedge sclk or negedge rst_n) begin
        if (!rst_n)
            slave_rx_shift = {DATA_WIDTH{1'b0}};
        else if (!cs_n)
            slave_rx_shift = {slave_rx_shift[DATA_WIDTH-2:0], mosi};
    end

    // The slave advances MISO after each falling SCLK edge.
    always @(negedge sclk or negedge rst_n or posedge cs_n) begin
        if (!rst_n || cs_n) begin
            miso = 1'b0;
        end else begin
            slave_tx_shift = {slave_tx_shift[DATA_WIDTH-2:0], 1'b0};
            miso = slave_tx_shift[DATA_WIDTH-1];
        end
    end

    task run_test;
        input [DATA_WIDTH-1:0] master_tx;
        input [DATA_WIDTH-1:0] expected_reply;
        integer errors_before;
        begin
            test_count = test_count + 1;
            errors_before = error_count;
            tx_data = master_tx;
            slave_reply = expected_reply;

            // Drive start away from the DUT's active clock edge.
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            if ((busy !== 1'b1) || (cs_n !== 1'b0)) begin
                $display("FAIL [%0d]: transfer did not become active", test_count);
                error_count = error_count + 1;
            end

            wait (done === 1'b1);
            #1;

            if (slave_rx_shift !== master_tx) begin
                $display("FAIL [%0d]: slave RX expected %02h, got %02h", test_count, master_tx, slave_rx_shift);
                error_count = error_count + 1;
            end

            if (rx_data !== expected_reply) begin
                $display("FAIL [%0d]: master RX expected %02h, got %02h", test_count, expected_reply, rx_data);
                error_count = error_count + 1;
            end

            if ((busy !== 1'b0) || (cs_n !== 1'b1) || (sclk !== 1'b0)) begin
                $display("FAIL [%0d]: bus did not return to idle", test_count);
                error_count = error_count + 1;
            end

            // done must be a one-system-clock pulse.
            @(posedge clk);
            #1;
            if (done !== 1'b0) begin
                $display("FAIL [%0d]: done is wider than one clock", test_count);
                error_count = error_count + 1;
            end

            if (error_count == errors_before)
                $display("PASS [%0d]: MOSI=%02h, MISO=%02h", test_count, master_tx, expected_reply);
        end
    endtask

    initial begin
        $dumpfile("tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);

        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        tx_data = {DATA_WIDTH{1'b0}};
        miso = 1'b0;
        slave_reply = {DATA_WIDTH{1'b0}};
        test_count = 0;
        error_count = 0;

        #40;
        rst_n = 1'b1;
        #20;

        $display("=== Testing spi_master (Mode 0) ===");
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
