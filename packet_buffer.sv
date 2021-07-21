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
	STATE_READING_HEADER_AND_CONTROL_READY,
	STATE_READING_HEADER_AND_DUMPING,
	STATE_READING_HEADER_AND_STREAMING,
	STATE_READING_BODY_AND_CONTROL_READY,
	STATE_READING_BODY_AND_DUMPING,
	STATE_READING_BODY_AND_STREAMING,
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

	/* When asserted, the packet header outputs are valid and a packet
	 * is in the buffer and ready to be routed. */
	output packet_ready,

	/* Header information, only valid when packet_ready is high. */
	output [TO_ADDR_MSB-TO_ADDR_LSB:0]             to_addr,
	output [FROM_ADDR_MSB-FROM_ADDR_LSB:0]         from_addr,
	output [PACKET_LENGTH_MSB-PACKET_LENGTH_LSB:0] packet_length,

	/* Number of packets and flits currently in the buffer. */
	output [$clog2(BUFFER_DEPTH)-1:0] n_packets,
	output [$clog2(BUFFER_DEPTH)-1:0] n_flits,

	/* Output used for streaming flits back out of the router. */
	output [FLIT_SIZE-1:0] out_flit,
	output out_flit_valid

);

packet_buffer_state state;

logic [FLIT_SIZE-1:0] ringbuffer [BUFFER_DEPTH-1:0];
logic [0:0] ringbuffer_valid [BUFFER_DEPTH-1:0];

/* The address at which the next incoming flit will be written. */
logic [$clog2(BUFFER_DEPTH)-1:0] ringbuffer_rxaddr;

/* The address which is currently being processed by stream/dump. */
logic [$clog2(BUFFER_DEPTH)-1:0] ringbuffer_headaddr;

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

initial begin
	state = STATE_IDLE;
end

always @(posedge clk) begin
	if !rst begin
		state <= STATE_IDLE;
		ringbuffer_rxaddr <= 0;
		ringbuffer_headaddr <= 0;
		rinbfuffer_valid[0] <= 0;
		n_packets <= 0;
		n_flits <= 0;
		packet_ready <= 0;
		flits_received <= 0;
	end else begin

		/* We are always able to accept an incoming flit */
		if in_flit_valid begin
			ringbuffer[ringbuffer_rxaddr] <= in_flit;
			ringbuffer_valid[ringbuffer_rxaddr] <= 1'b1;
			rinbuffer_rxaddr <= ringbuffer_rxaddr + 1;
			n_flits <= n_flits + 1;
			packet_ready <= 1;
			flits_received <= flits_received + 1;
		end


		case (state)
			STATE_IDLE: begin
				if in_flit_valid begin
					state <= STATE_READING_HEADER;
					header <= in_flit;
					n_packets <= n_packets + 1;
					flits_received <= 0;
				end else begin
					state <= STATE_IDLE;
				end
			end

			STATE_READING_HEADER_AND_CONTROL_READY: begin
				if in_flit_valid && (control_valid) && (stream) && (!drop) begin
					state <= STATE_READING_BODY_AND_STREAMING;

				end else if in_flit_valid && (control_valid) && (!stream) && (drop) begin
					state <= STATE_READING_BODY_AND_DUMPING;

				end else if in_flit_valid && (!control_valid) begin
					state <= STATE_READING_BODY_AND_CONTROL_READY;

				end else begin
					state <= CONTROL_READY;

				end

			end

			STATE_READING_BODY_AND_CONTROL_READY begin
				if in_flit_valid && (control_valid) && (stream) && (!drop) && (flits_received <= packet_length) begin
					state <= STATE_READING_BODY_AND_STREAMING;

				end else if in_flit_valid && (control_valid) && (stream) && (!drop) && (flits_received > packet_length) begin
					state <= STATE_READING_HEADER_AND_STREAMING;
					flits_received <= 0;

				end else if in_flit_valid && (control_valid) && (!stream) && (drop) && (flits_received <= packet_length) begin
					state <= STATE_READING_BODY_AND_DUMPING;

				end else if in_flit_valid && (control_valid) && (!stream) && (drop) && (flits_received > packet_length) begin
					state <= STATE_READING_HEADER_AND_DUMPING;
					flits_received <= 0;

				end else if in_flit_valid && (!control_valid) && (flits_received <= packet_length) begin
					state <= STATE_READING_BODY_AND_CONTROL_READY;

				end else if in_flit_valid && (!control_valid) && (flits_received > packet_length) begin
					state <= STATE_READING_HEADER_AND_CONTROL_READY;
					flits_received <= 0;

				end else begin
					state <= CONTROL_READY;

				end
			end
		endcase
	end



end

endmodule
