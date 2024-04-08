module fifo(input clk, rst_n,rd_en,wr_en, output reg [31:0] rd_data, input [31:0] wr_data,
		output full, empty);

logic [3:0] wr_ptr;
logic [3:0] rd_ptr;
logic [4:0] cnt;

logic [31:0] fifo_data [15:0];


always @(posedge clk or negedge rst_n) begin

	if(!rst_n)begin
		wr_ptr <= 'b0;
		rd_ptr <= 'b0;
      	fifo_data[15:0] <= '{default:'0};
      	cnt <= 'b0;
	end
	else if (rd_en && !empty) begin
		rd_data <= fifo_data[rd_ptr];
		rd_ptr <= rd_ptr + 1'b1;	
		cnt <= cnt - 1'b1;
	end else if (wr_en && !full) begin
		fifo_data[wr_ptr] <= wr_data;
		wr_ptr <= wr_ptr + 1'b1;
		cnt <= cnt + 1'b1;
	end 
	else begin
		rd_data <= 'b0;
		cnt <= cnt;
		rd_ptr <= rd_ptr;
		wr_ptr <= wr_ptr;
	end


end

assign full = (cnt == 'd16) ? 1'b1 :1'b0;
assign empty = (cnt == 'd0) ? 1'b1 :1'b0;

endmodule

interface inter;
	logic clk;
	logic rst_n;
	logic [31:0] rd_data;
	logic [31:0] wr_data;
	logic wr_en;
	logic rd_en;
	logic full;
	logic empty;

endinterface
