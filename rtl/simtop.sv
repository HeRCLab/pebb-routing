module simtop (
	input clk,
	output [8:0] foo
);

logic [7:0] counter;

assign foo = counter*2;

initial begin
	counter = 0;
end

always @(posedge clk) begin
	counter <= counter + 1;
end

endmodule
