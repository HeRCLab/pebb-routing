import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb.binary import BinaryValue

import random

import struct

def pack_header(to_addr, from_addr, length):
        return BinaryValue(struct.pack("BBBxxxxx", to_addr, from_addr, length))

async def simulate_packetbuffer(dut, packets, actions, do_assert=True, max_iter = None):
    # Given a list of packets and a list of actions, run the packet buffer
    # until after all packets have been fully processed. The return will
    # be a list of packets which were streamed. This simulation uses the
    # tightest possible timings, streaming in one flit per cycle, and issuing
    # commands as soon as the packet becomes ready.
    #
    # Packet lists are formatted as a list of lists, with the inner lists
    # being 64-bit long bytes objects, each representing a flit.
    #
    # actions[i] being True indicates that packets[i] should be passed, and
    # the inverse means it packets[i] should be dropped.
    #
    # The dut is not reset before running the simulation.
    #
    # If do_assert is asserted, then this function will also perform assertions
    # to check that the module behaved correctly.
    #
    # If the simulation loop for this function runs for more than 2x the total
    # number of flits in the input, it will automatically fail via assert
    # False.
    #
    # If max_iter is an integer, then this method will assert that the test
    # finished in no more than the specified number of iterations.

    outputs = []

    # Count the number of input flits so that we have a guaranteed end condition
    # even if the DUT isn't working properly.
    input_flits = 0
    for packetNo in range(len(packets)):
        input_flits += len(packets[packetNo])

    # Track where we are in the inputs.
    packetNo = 0
    flitNo = 0

    # What packet number are we currently processing, e.g. what's the index
    # into packets actions?
    processed = 0

    iterations = 0
    while True:
        iterations += 1

        await(FallingEdge(dut.clk))
        if dut.out_flit_valid == 1:
            outputs.append(dut.out_flit)

        await(RisingEdge(dut.clk))
        if (packetNo < len(packets)) and (flitNo < len(packets[packetNo])):

            if not isinstance(packets[packetNo][flitNo], BinaryValue):
                packets[packetNo][flitNo] = BinaryValue(packets[packetNo][flitNo])

            dut.in_flit <= packets[packetNo][flitNo]
            dut.in_flit_valid <= 1

            if flitNo >= len(packets[packetNo]):
                flitNo = 0
                packetNo += 1
            else:
                flitNo += 1

        else:
            dut.in_flit_valid <= 0

        if (dut.control_ready == 1) and (processed < len(packets)):
            dut.control_valid <= 1
            if actions[processed]:
                dut.stream <= 1
                dut.drop <= 0
            else:
                dut.stream <= 0
                dut.drop <= 1
            processed += 1
        else:
            dut.control_valid <= 0
            dut.stream <= 0
            dut.drop <= 0

        if (processed >= len(packets)) and (packetNo >= len(packets)) and (flitNo >= len(packets[-1])) and (dut.n_flits == 0) and (dut.n_packets == 0):
            break

        assert iterations < (2 * input_flits)

    if max_iter is not None:
        assert iterations <= max_iter

    if do_assert:
        expect = []
        for packetNo in range(len(packets)):
            if not actions[packetNo]:
                continue

            for flitNo in range(len(packets[packetNo])):
                expect.append(packets[packetNo][flitNo])

        for i in range(len(expect)):
            assert expect[i] == outputs[i]

    return outputs

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

@cocotb.test()
async def test_packet_buffer_3(dut):
    # This is a simple test of the packet buffer using the
    # simulate_packetbuffer() method, which runs on just one single input
    # packet.

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

    packets = [ [pack_header(23, 5, 3), struct.pack("Q", 0x123), struct.pack("Q", 0x456) ] ]
    actions = [ True ]

    await(simulate_packetbuffer(dut, packets, actions))

@cocotb.test()
async def test_packet_buffer_4(dut):
    # This represents a more complex test of the packet buffer, consisting of
    # 10 packets, some dropped and some forwarded, and of varying lengths.

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

    packets = [
            [pack_header(23, 5, 3), struct.pack("Q", 0x123), struct.pack("Q", 0x456)],
            [pack_header(23, 17, 5), struct.pack("Q", 0x123), struct.pack("Q", 0x456), struct.pack("Q", 0x111), struct.pack("Q", 0x222)],
            [pack_header(19, 5, 3), struct.pack("Q", 0xF0F0F0), struct.pack("Q", 0xFFFF)],
            [pack_header(23, 5, 3), struct.pack("Q", 0x11111111), struct.pack("Q", 0x22222222)],
            [pack_header(23, 5, 3), struct.pack("Q", 0x33333333), struct.pack("Q", 0x44444444)],
            [pack_header(19, 5, 2), struct.pack("Q", 0x12121212)],
            [pack_header(23, 5, 3), struct.pack("Q", 0x33333333), struct.pack("Q", 0x44444444)],
            [pack_header(19, 5, 20), *[struct.pack("Q", i) for i in range(100, 120)]],
            [pack_header(23, 5, 20), *[struct.pack("Q", i) for i in range(200, 220)]],
            [pack_header(23, 17, 5), struct.pack("Q", 0x1010), struct.pack("Q", 0x2020), struct.pack("Q", 0x3030), struct.pack("Q", 0x4040)],
    ]
    actions = [
            True,
            True,
            False,
            True,
            True,
            False,
            True,
            False,
            True,
            True
    ]

    flits = 3+5+3+3+3+2+3+20+20+5

    await(simulate_packetbuffer(dut, packets, actions, max_iter = flits+1))
