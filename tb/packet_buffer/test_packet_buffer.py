import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb.binary import BinaryValue

import random

import struct

def pack_header(to_addr, from_addr, length):
        return BinaryValue(struct.pack("BBBxxxxx", to_addr, from_addr, length))

@cocotb.test()
async def test_packet_buffer_1(dut):
    clock = Clock(dut.clk, 10, units="us")
    cocotb.fork(clock.start())

    # Reset the module
    await(FallingEdge(dut.clk))
    await(RisingEdge(dut.clk))
    dut.rst <= 0
    await(RisingEdge(dut.clk))
    dut.rst <= 1
    await(RisingEdge(dut.clk))

    # The header should be parsed and the packet ready for consideration
    # On the next rising clock edge after the flit is passed in.
    header = pack_header(23, 5, 3)
    dut.in_flit <= header
    dut.in_flit_valid <= 1
    await(RisingEdge(dut.clk))
    dut.in_flit <= random.randint(0, 2**63) # Clock in the first data flit
    await(RisingEdge(dut.clk))
    assert dut.packet_ready == 1
    assert dut.header == header
    assert dut.from_addr == 5
    assert dut.to_addr == 23
    assert dut.packet_length == 3
    assert dut.n_packets == 1
    assert dut.n_flits == 1

    # With a packet length of 3, we need to clock in one additional data flit.
    dut.in_flit <= random.randint(0, 2**63)
    await(RisingEdge(dut.clk))
    dut.in_flit_valid <= 0

    # We should have now clocked in all 3 data flits, and since we haven't
    # dumped or streamed any packets, the header should remain the same.
    await(RisingEdge(dut.clk))
    assert dut.packet_ready == 1
    assert dut.header == header
    assert dut.from_addr == 5
    assert dut.to_addr == 23
    assert dut.packet_length == 3
    assert dut.n_packets == 1
    assert dut.n_flits == 3
