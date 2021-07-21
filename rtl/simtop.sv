`define DATA_WIDTH 64
`define KEEP_WIDTH 8
`define ID_WIDTH 8
`define DEST_WIDTH 8
`define USER_WIDTH 1

module simtop (
	input clk,
	input rst,

	output logic [`DATA_WIDTH-1:0]         m_axis_tdata_1,
	output logic [`KEEP_WIDTH-1:0]         m_axis_tkeep_1,
	output logic                           m_axis_tvalid_1,
	input  logic                           m_axis_tready_1,
	output logic                           m_axis_tlast_1,
	output logic [`ID_WIDTH-1:0]           m_axis_tid_1,
	output logic [`DEST_WIDTH-1:0]         m_axis_tdest_1,
	output logic                           m_axis_aclk_1,
	output logic                           m_axis_aresetn_1,

	output logic [`DATA_WIDTH-1:0]         m_axis_tdata_2,
	output logic [`KEEP_WIDTH-1:0]         m_axis_tkeep_2,
	output logic                           m_axis_tvalid_2,
	input  logic                           m_axis_tready_2,
	output logic                           m_axis_tlast_2,
	output logic [`ID_WIDTH-1:0]           m_axis_tid_2,
	output logic [`DEST_WIDTH-1:0]         m_axis_tdest_2,
	output logic                           m_axis_aclk_2,
	output logic                           m_axis_aresetn_2,

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

router #(.ADDRESS(1)) router0(
	.m_axis_tdata(m_axis_tdata_1),
	.m_axis_tkeep(m_axis_tkeep_1),
	.m_axis_tvalid(m_axis_tvalid_1),
	.m_axis_tready(m_axis_tready_1),
	.m_axis_tlast(m_axis_tlast_1),
	.m_axis_tid(m_axis_tid_1),
	.m_axis_tdest(m_axis_tdest_1),
	.m_axis_aclk(m_axis_aclk_1),
	.m_axis_aresetn(m_axis_aresetn_1),
	.s_axis_tdata_1(s_axis_tdata_1),
	.s_axis_tkeep_1(s_axis_tkeep_1),
	.s_axis_tvalid_1(s_axis_tvalid_1),
	.s_axis_tready_1(s_axis_tready_1),
	.s_axis_tlast_1(s_axis_tlast_1),
	.s_axis_tid_1(s_axis_tid_1),
	.s_axis_tdest_1(s_axis_tdest_1),
	.s_axis_aclk_1(s_axis_aclk_1),
	.s_axis_aresetn_1(s_axis_aresetn_1),
	.s_axis_tdata_2(s_axis_tdata_2),
	.s_axis_tkeep_2(s_axis_tkeep_2),
	.s_axis_tvalid_2(s_axis_tvalid_2),
	.s_axis_tready_2(s_axis_tready_2),
	.s_axis_tlast_2(s_axis_tlast_2),
	.s_axis_tid_2(s_axis_tid_2),
	.s_axis_tdest_2(s_axis_tdest_2),
	.s_axis_aclk_2(s_axis_aclk_2),
	.s_axis_aresetn_2(s_axis_aresetn_2)
);


endmodule
