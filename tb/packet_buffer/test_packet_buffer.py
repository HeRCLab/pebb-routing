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
    # This simple test ensures that the packet buffer can receive a single
    # packet with multiple flits, and that the header remains exposed correctly
    # as the flits are clocked in.

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

@cocotb.test()
async def test_packet_buffer_2(dut):
    # This test inserts two packets of three flits each, then streams out the
    # first and dumps the second. This is the simplest case, since we don't
    # begin streaming or dumping any flits until after both packets are fully
    # read in, and we take a gap cycle in between streaming in packets.

    clock = Clock(dut.clk, 10, units="us")
    cocotb.fork(clock.start())

    dut.in_flit <= 0
    dut.in_flit_valid <= 0
    dut.drop <= 0
    dut.stream <= 0
    dut.control_valid <= 0

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
    rand1 = random.randint(0, 2**63)
    dut.in_flit <=  rand1 # Clock in the first data flit
    await(RisingEdge(dut.clk))
    assert dut.packet_ready == 1
    assert dut.header == header
    assert dut.from_addr == 5
    assert dut.to_addr == 23
    assert dut.packet_length == 3
    assert dut.n_packets == 1
    assert dut.n_flits == 1

    # With a packet length of 3, we need to clock in one additional data flit.
    rand2 = random.randint(0, 2**63)
    dut.in_flit <= rand2
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

    # We now stream in the second packet
    header2 = pack_header(78, 34, 3)
    dut.in_flit <= header2
    dut.in_flit_valid <= 1
    await(RisingEdge(dut.clk))
    dut.in_flit <= random.randint(0, 2**63) # Clock in the first data flit
    await(RisingEdge(dut.clk))
    assert dut.packet_ready == 1
    assert dut.header == header
    assert dut.from_addr == 5
    assert dut.to_addr == 23
    assert dut.packet_length == 3
    assert dut.n_packets == 2
    assert dut.n_flits == 4

    # With a packet length of 3, we need to clock in one additional data flit.
    dut.in_flit <= random.randint(0, 2**63)
    await(RisingEdge(dut.clk))
    dut.in_flit_valid <= 0
    await(RisingEdge(dut.clk))
    assert dut.packet_ready == 1
    assert dut.header == header
    assert dut.from_addr == 5
    assert dut.to_addr == 23
    assert dut.packet_length == 3
    assert dut.n_packets == 2
    assert dut.n_flits == 6

    # Stream out the first packet.
    assert dut.control_ready == 1
    dut.stream <= 1
    dut.control_valid <= 1

    # Packet header should be streaming out.
    await(RisingEdge(dut.clk))
    dut.stream <= 0
    dut.control_valid <= 0
    await(FallingEdge(dut.clk))
    assert dut.control_ready == 0
    assert dut.n_flits == 5
    assert dut.n_packets == 2
    assert dut.out_flit_valid ==1
    assert dut.out_flit == header

    await(FallingEdge(dut.clk))
    assert dut.control_ready == 0
    assert dut.n_flits == 4
    assert dut.n_packets == 2
    assert dut.out_flit_valid ==1
    assert dut.out_flit == rand1

    await(FallingEdge(dut.clk))
    assert dut.n_flits == 3
    assert dut.out_flit_valid ==1
    assert dut.out_flit == rand2

    # Now the next packet should be ready for processing.
    assert dut.control_ready == 1
    assert dut.n_packets == 1
    assert dut.packet_ready == 1
    assert dut.header == header2
    assert dut.to_addr == 78
    assert dut.from_addr == 34
    assert dut.packet_length == 3

    # Everything should remain steady even if we wait for a while.
    await(FallingEdge(dut.clk))
    await(FallingEdge(dut.clk))
    await(FallingEdge(dut.clk))
    assert dut.control_ready == 1
    assert dut.packet_ready == 1
    assert dut.n_packets == 1
    assert dut.n_flits == 3

    # we'll drop the next packet
    await(FallingEdge(dut.clk))
    dut.drop <= 1
    dut.control_valid <= 1
    await(FallingEdge(dut.clk))
    dut.drop <= 0
    dut.control_valid <= 0


    await(RisingEdge(dut.clk))
    assert dut.out_flit_valid == 0
    assert dut.control_ready == 0
    assert dut.packet_ready == 1
    assert dut.n_packets == 1
    assert dut.n_flits == 2
    assert dut.header == header2
    assert dut.to_addr == 78
    assert dut.from_addr == 34
    assert dut.packet_length == 3

    await(RisingEdge(dut.clk))
    assert dut.out_flit_valid == 0
    assert dut.control_ready == 0
    assert dut.packet_ready == 1
    assert dut.n_packets == 1
    assert dut.n_flits == 1
    assert dut.header == header2
    assert dut.to_addr == 78
    assert dut.from_addr == 34
    assert dut.packet_length == 3

    await(RisingEdge(dut.clk))
    assert dut.out_flit_valid == 0
    assert dut.control_ready == 0
    assert dut.packet_ready == 0
    assert dut.n_packets == 0
    assert dut.n_flits == 0
