# Common waveform setup for all SPI testbenches.
# The active top-level testbench is detected automatically.

quietly WaveActivateNextPane {} 0

if {![catch {examine sim:/tb_spi_master/clk}]} {
    add wave -noupdate -divider {System interface}
    add wave -noupdate sim:/tb_spi_master/clk
    add wave -noupdate sim:/tb_spi_master/rst_n
    add wave -noupdate sim:/tb_spi_master/start
    add wave -noupdate sim:/tb_spi_master/busy
    add wave -noupdate sim:/tb_spi_master/done
    add wave -noupdate -radix hexadecimal sim:/tb_spi_master/tx_data
    add wave -noupdate -radix hexadecimal sim:/tb_spi_master/rx_data

    add wave -noupdate -divider {SPI bus}
    add wave -noupdate sim:/tb_spi_master/cs_n
    add wave -noupdate sim:/tb_spi_master/sclk
    add wave -noupdate sim:/tb_spi_master/mosi
    add wave -noupdate sim:/tb_spi_master/miso

    add wave -noupdate -divider {Slave model}
    add wave -noupdate -radix hexadecimal sim:/tb_spi_master/slave_reply
    add wave -noupdate -radix hexadecimal sim:/tb_spi_master/slave_rx_shift
} elseif {![catch {examine sim:/tb_spi_slave/sclk}]} {
    add wave -noupdate -divider {SPI bus}
    add wave -noupdate sim:/tb_spi_slave/rst_n
    add wave -noupdate sim:/tb_spi_slave/cs_n
    add wave -noupdate sim:/tb_spi_slave/sclk
    add wave -noupdate sim:/tb_spi_slave/mosi
    add wave -noupdate sim:/tb_spi_slave/miso
    add wave -noupdate sim:/tb_spi_slave/miso_oe

    add wave -noupdate -divider {Slave data and status}
    add wave -noupdate -radix hexadecimal sim:/tb_spi_slave/tx_data
    add wave -noupdate -radix hexadecimal sim:/tb_spi_slave/rx_data
    add wave -noupdate sim:/tb_spi_slave/rx_valid
    add wave -noupdate sim:/tb_spi_slave/busy
} elseif {![catch {examine sim:/tb_spi_loopback/clk}]} {
    add wave -noupdate -divider {System interface}
    add wave -noupdate sim:/tb_spi_loopback/clk
    add wave -noupdate sim:/tb_spi_loopback/rst_n
    add wave -noupdate sim:/tb_spi_loopback/start

    add wave -noupdate -divider {Master data and status}
    add wave -noupdate -radix hexadecimal sim:/tb_spi_loopback/master_tx_data
    add wave -noupdate -radix hexadecimal sim:/tb_spi_loopback/master_rx_data
    add wave -noupdate sim:/tb_spi_loopback/master_busy
    add wave -noupdate sim:/tb_spi_loopback/master_done

    add wave -noupdate -divider {SPI bus}
    add wave -noupdate sim:/tb_spi_loopback/cs_n
    add wave -noupdate sim:/tb_spi_loopback/sclk
    add wave -noupdate sim:/tb_spi_loopback/mosi
    add wave -noupdate sim:/tb_spi_loopback/miso
    add wave -noupdate sim:/tb_spi_loopback/miso_oe

    add wave -noupdate -divider {Slave data and status}
    add wave -noupdate -radix hexadecimal sim:/tb_spi_loopback/slave_tx_data
    add wave -noupdate -radix hexadecimal sim:/tb_spi_loopback/slave_rx_data
    add wave -noupdate sim:/tb_spi_loopback/slave_rx_valid
    add wave -noupdate sim:/tb_spi_loopback/slave_busy
} else {
    echo "wave.do: expected an SPI testbench top level"
}

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -timelineunits ns
update

run -all
wave zoom full
