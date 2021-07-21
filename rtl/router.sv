/* This router module considers packets incoming from multiple inbound AXI-S
 * links, discarding those packets it does not want and passing on those it
 * does.
 *
 * The following header packet format is used:
 * * 63:56 - destination address
 * * 55:48 - source address
 * * 47:40 - packet length
 * * 39:0 - unused
 *
 * TODO: this is not the packet format Aaron created, need to go back and
 * reconcile this later.
 *
 */

module router #
(
	/* Defines the address of the router. */
	parameter ADDRESS
)
(
	output logic [`DATA_WIDTH-1:0]         m_axis_tdata,
	output logic [`KEEP_WIDTH-1:0]         m_axis_tkeep,
	output logic                           m_axis_tvalid,
	input  logic                           m_axis_tready,
	output logic                           m_axis_tlast,
	output logic [`ID_WIDTH-1:0]           m_axis_tid,
	output logic [`DEST_WIDTH-1:0]         m_axis_tdest,
	output logic                           m_axis_aclk,
	output logic                           m_axis_aresetn,

	output logic [`DATA_WIDTH-1:0]         s_axis_tdata_1,
	output logic [`KEEP_WIDTH-1:0]         s_axis_tkeep_1,
	output logic                           s_axis_tvalid_1,
	input  logic                           s_axis_tready_1,
	output logic                           s_axis_tlast_1,
	output logic [`ID_WIDTH-1:0]           s_axis_tid_1,
	output logic [`DEST_WIDTH-1:0]         s_axis_tdest_1,
	input logic                            s_axis_aclk_1,
	input logic                            s_axis_aresetn_1,

	output logic [`DATA_WIDTH-1:0]         s_axis_tdata_2,
	output logic [`KEEP_WIDTH-1:0]         s_axis_tkeep_2,
	output logic                           s_axis_tvalid_2,
	input  logic                           s_axis_tready_2,
	output logic                           s_axis_tlast_2,
	output logic [`ID_WIDTH-1:0]           s_axis_tid_2,
	output logic [`DEST_WIDTH-1:0]         s_axis_tdest_2,
	input logic                            s_axis_aclk_2,
	input logic                            s_axis_aresetn_2
);

/* The address of this particular router */
logic [7:0] address;
assign address = ADDRESS;



endmodule
