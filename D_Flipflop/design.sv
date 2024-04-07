module dff (interf_dff dif);
  
  always @(posedge dif.clk or negedge dif.rst_n) begin
    if (!dif.rst_n) begin
      dif.dout <= 1'b0;
    end else begin
      dif.dout <= dif.din; 
    end
  end
endmodule

interface interf_dff;
  logic clk;
  logic rst_n;
  logic din;
  logic dout;
  
endinterface 
