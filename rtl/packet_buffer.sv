/* This module implements a packet buffer, which can on each cycle read in a
 * single flit, and can be instructed to either re-transmit an entire
 * multi-flit packet, or to drop it. Operation is governed by the following
 * state machine:
 *
 *
 *           ┌─────────────────────────────────┐
 *           │                                 │
 * reset     │               ┌───┐             │
 *   │       │               │12 │             │
 *   │ ┌─────┘           13 ┌┴───▼──┐11        │
 *   │ │           ┌────────┤Dumping├───────┐  │
 * ┌─▼─▼┐          │        └▲──────┘       │  │
 * │Idle◄──────────┘         │              │  │
 * └─┬──┘                    └──────────┐   │  │
 *   │1                                 │   │  │
 *   ├────────────────────────┐  ┌───┐  │   │  │
 *   │                        │  │ 9 │  │10 │  │
 * ┌─▼────────────┐         ┌─▼──┴───▼──┴─┐ │  │
 * │Reading Header◄─┐       │Control Ready◄─┘  │
 * └─┬────────────┘ │       └─┬───▲───────┘    │
 *   │              │         │   │            │
 *   │2             │         │7  │8           │
 *   │              │         │   │            │
 * ┌─▼──────────┐4  │       ┌─▼───┴───┐6       │
 * │Reading Body├───┘       │Streaming├────────┘
 * └─┬───▲──────┘           └─┬───▲───┘
 *   │ 3 │                    │5  │
 *   └───┘                    └───┘
 *
 *
 *  1: Flit received.
 *
 *  2: Flit received.
 *
 *  3: Flit received, still reading current packet.
 *
 *  4: Flit received, done reading current packet.
 *
 *  5: Streaming in progress, still sending current packet.
 *
 *  6: Streaming done, buffer empty.
 *
 *  7: Stream command issued.
 *
 *  8: Streaming done, buffer non-empty.
 *
 *  9: Buffer non-empty, no command issued.
 *
 * 10: Dump command issued.
 *
 * 11: Dumping done, buffer non-empty.
 *
 * 12: Dumping in progress, still dumping current packet.
 *
 * 13: Dumping done, buffer empty.
 *
 * Note that the state machine is shown as an NFA, but is internally
 * implemented as a DFA.
 */


typedef enum {
	STATE_IDLE,
	STATE_READING_HEADER,
	STATE_READING_BODY,
	STATE_CONTROL_READY,
	STATE_DUMPING,
	STATE_STREAMING
} packet_buffer_state;

module packet_buffer #
(
	/* The maximum number of flits that can be stored in the buffer. Must
	 * be a power of 2. */
	parameter BUFFER_DEPTH = 256,

	/* The size of 1 flit in bits. */
	parameter FLIT_SIZE = 64,

	/* The subscript into the header flit where the to address is stored.
	 * */
	parameter TO_ADDRESS_MSB = 63,
	parameter TO_ADDRESS_LSB = 56,

	/* The subscript into the header flit where the from address is
	 * stored. */
	parameter FROM_ADDRESS_MSB = 55,
	parameter FROM_ADDRESS_LSB = 48,

	/* The subscripts into the header flit where the packet length is
	 * stored */
	parameter PACKET_LENGTH_MSB = 47,
	parameter PACKET_LENGTH_LSB = 40
)
(
	input clk,
	input rst, /* Active-low */

	input [FLIT_SIZE-1:0] in_flit,

	/* On the rising clock edge, the input flit is read if this is
	 * asserted. */
	input in_flit_valid,

	/* On a rising clock edge, if control_valid is asserted and drop is
	 * asserted, a "drop" command is issued. */
	input drop,

	/* As with drop, but for a "stream" command. */
	input stream,

	input control_valid,

	/* When this signal is asserted, the packet buffer is able to accept
	 * commands. Commands sent when this signal is low will be ignored. */
	output logic control_ready,

	/* When asserted, the packet header outputs are valid and a packet
	 * is in the buffer and ready to be routed. */
	output logic packet_ready,

	/* Header information, only valid when packet_ready is high. */
	output logic [TO_ADDRESS_MSB-TO_ADDRESS_LSB:0]             to_addr,
	output logic [FROM_ADDRESS_MSB-FROM_ADDRESS_LSB:0]         from_addr,
	output logic [PACKET_LENGTH_MSB-PACKET_LENGTH_LSB:0] packet_length,

	/* Number of packets and flits currently in the buffer. */
	output logic [$clog2(BUFFER_DEPTH)-1:0] n_packets,
	output logic [$clog2(BUFFER_DEPTH)-1:0] n_flits,

	/* Output used for streaming flits back out of the router. */
	output logic [FLIT_SIZE-1:0] out_flit,
	output logic out_flit_valid

);


`ifdef COCOTB_SIM
initial begin
	$dumpfile("packet_buffer.vcd");
	$dumpvars(2, packet_buffer);
	#1;
end
`endif

/* To simply implementing the state machine, we take advantage of the fact
 * that the (Idle, Reading Header, Reading Body) portion of the SM is
 * independant from the (Dumping, Control Ready, Streaming) portion of the SM.
 */

packet_buffer_state state_control;
packet_buffer_state state_buffer;

logic [FLIT_SIZE-1:0] ringbuffer [BUFFER_DEPTH-1:0];
logic [0:0] ringbuffer_valid [BUFFER_DEPTH-1:0];

/* The address at which the next incoming flit will be written. */
logic [$clog2(BUFFER_DEPTH)-1:0] ringbuffer_rxaddr;

/* The address which is currently being processed by stream/dump. */
logic [$clog2(BUFFER_DEPTH)-1:0] ringbuffer_headaddr;

/* The address containing the header of the current packet. */
logic [$clog2(BUFFER_DEPTH)-1:0] ringbuffer_packet_head_addr;

/* Used as an internal counter for dump/stream to track how many flits
 * have so far been considered. */
logic [$clog2(BUFFER_DEPTH)-1:0] flits_processed;

/* Tracks the number of flits for the current packet that have been received
 * so far. */
logic [$clog2(BUFFER_DEPTH)-1:0] flits_received;

/* The header flit of the current packet. */
logic [FLIT_SIZE-1:0] header;

assign to_addr       = header[TO_ADDRESS_MSB   :TO_ADDRESS_LSB   ];
assign from_addr     = header[FROM_ADDRESS_MSB :FROM_ADDRESS_LSB ];
assign packet_length = header[PACKET_LENGTH_MSB:PACKET_LENGTH_LSB];

assign control_ready = (state_control == STATE_CONTROL_READY) && (!rst);

initial begin
	state_buffer = STATE_IDLE;
	state_control = STATE_IDLE;
	ringbuffer_rxaddr = 0;
	ringbuffer_headaddr = 0;
	ringbuffer_valid[0] = 0;
	n_packets = 0;
	n_flits = 0;
	packet_ready = 0;
	flits_received = 0;
	ringbuffer_packet_head_addr = 0;
end

always @(posedge clk) begin
	if (!rst) begin
		state_control <= STATE_IDLE;
		state_buffer <= STATE_IDLE;
		ringbuffer_rxaddr <= 0;
		ringbuffer_headaddr <= 0;
		ringbuffer_valid[0] <= 0;
		n_packets <= 0;
		n_flits <= 0;
		packet_ready <= 0;
		flits_received <= 0;
		ringbuffer_packet_head_addr <= 0;
	end else begin
		/* We are always able to accept an incoming flit */
		if (in_flit_valid) begin
			ringbuffer[ringbuffer_rxaddr] <= in_flit;
			ringbuffer_valid[ringbuffer_rxaddr] <= 1'b1;
			ringbuffer_rxaddr <= ringbuffer_rxaddr + 1;
			n_flits <= n_flits + 1;
			packet_ready <= 1;
			flits_received <= flits_received + 1;
		end

		case (state_buffer)
			STATE_IDLE: begin
				if (in_flit_valid) begin
					state_buffer <= STATE_READING_HEADER;
					ringbuffer_packet_head_addr <= ringbuffer_rxaddr;
					header <= in_flit;
					n_packets <= n_packets + 1;
					flits_received <= 1;
				end
			end

			STATE_READING_HEADER: begin
				state_buffer <= STATE_READING_BODY;
			end

			STATE_READING_BODY: begin

				// NOTE: this assumes the packet_length
				// includes the header flit.
				if (flits_received >= packet_length) begin
					state_buffer <= STATE_IDLE;
				end else begin
					state_buffer <= STATE_READING_BODY;
				end
			end

		endcase

		case (state_control)
			STATE_IDLE: begin
				if (in_flit_valid) begin
					state_control <= STATE_CONTROL_READY;
				end
			end

			STATE_CONTROL_READY: begin
				/* Notice that if we receive a stream or dump
				 * command, we begin processing it
				 * immediately */

				if ((control_valid) && (drop) && (!stream)) begin
					state_control <= STATE_DUMPING;
					out_flit_valid <= 0;
					ringbuffer_valid[ringbuffer_headaddr] = 0;
					ringbuffer_headaddr <= ringbuffer_headaddr + 1;

				end else if ((control_valid) && (!drop) && (stream)) begin
					state_control <= STATE_STREAMING;
					out_flit <= ringbuffer[ringbuffer_headaddr];
					ringbuffer_valid[ringbuffer_headaddr] = 0;
					out_flit_valid <= 1;
					ringbuffer_headaddr <= ringbuffer_headaddr + 1;

				end else begin

					state_control <= STATE_CONTROL_READY;
				end
			end

			STATE_STREAMING: begin
				/* Check if we have finished streaming the
				 * whole packet */
				if ((ringbuffer_headaddr+1) > (ringbuffer_packet_head_addr + packet_length)) begin
					if (n_packets > 1) begin
						state_control <= STATE_CONTROL_READY;
					end else begin
						state_control <= STATE_IDLE;
					end

					out_flit_valid <= 0;
					n_packets <= n_packets - 1;
				end else begin
					state_control <= STATE_STREAMING;
				end

				ringbuffer_valid[ringbuffer_headaddr] = 0;
				out_flit <= ringbuffer[ringbuffer_headaddr];
				out_flit_valid <= 1;
				ringbuffer_headaddr <= ringbuffer_headaddr + 1;

			end

			STATE_DUMPING: begin
				/* Check if we have finished dropping the
				 * whole packet */
				if ((ringbuffer_headaddr+1) > (ringbuffer_packet_head_addr + packet_length)) begin
					if (n_packets > 1) begin
						state_control <= STATE_CONTROL_READY;
					end else begin
						state_control <= STATE_IDLE;
					end

					out_flit_valid <= 0;
					n_packets <= n_packets - 1;
				end else begin
					state_control <= STATE_DUMPING;
				end

				ringbuffer_valid[ringbuffer_headaddr] = 0;
				out_flit_valid <= 0;
				ringbuffer_headaddr <= ringbuffer_headaddr + 1;

			end
		endcase
	end

end

endmodule
