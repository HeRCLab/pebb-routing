import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb.binary import BinaryValue

import struct

def pack_header(to_addr, from_addr, length):
        return BinaryValue(struct.pack("BBBxxxxx", to_addr, from_addr, length))

@cocotb.test()
async def test_packet_buffer_1(dut):
    clock = Clock(dut.clk, 10, units="us")
    cocotb.fork(clock.start())

    await(FallingEdge(dut.clk))
    await(RisingEdge(dut.clk))
    dut.rst <= 0
    await(FallingEdge(dut.clk))
    await(RisingEdge(dut.clk))
    dut.rst <= 1
    await(FallingEdge(dut.clk))
    await(RisingEdge(dut.clk))

    header = pack_header(23, 5, 1)
    dut.in_flit <= header
    dut.in_flit_valid <= 1

    await(FallingEdge(dut.clk))
    await(RisingEdge(dut.clk))
    await(FallingEdge(dut.clk))
    await(RisingEdge(dut.clk))

    dut.in_flit_valid <= 0

    assert dut.packet_ready == 1
    assert dut.header == header
    assert dut.from_addr == 5
    assert dut.to_addr == 23
    assert dut.packet_length == 1

