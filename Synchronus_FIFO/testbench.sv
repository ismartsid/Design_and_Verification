
class transaction;
  rand bit wr_en,rd_en;
  rand bit [31:0] wr_data;
  bit [31:0] rd_data;
  bit full, empty;
    
  constraint rd_wr { (wr_en == 1) <-> (rd_en == 0);
                   	rd_en dist {0:=40, 1:= 60};
                    wr_en dist {0:=50, 1:= 25};
                   }
  
  constraint rd_wrdata { (rd_en == 1) -> (wr_data == 0); }
  
  
  function void display(input string tag);
   $display("[%0s]: wr_en =%0d, rd_en =%0d, wr_data =%0d, rd_data =%0d, full =%0d, empty =%0d",tag, wr_en, rd_en, wr_data, rd_data, full, empty);
  endfunction

endclass


class generator;
  transaction gen_tr;
  mailbox #(transaction) gen_drv;
  
  event next,done;
  int count; 

  function new(mailbox #(transaction) gen_drv);
	gen_tr = new();
	this.gen_drv = gen_drv;
  endfunction
  
  task main();
    repeat(count) begin
      assert(gen_tr.randomize) else begin 
        $display("Randomiztion Failed at %0t", $time);
        $finish;
      end
      gen_drv.put(gen_tr);
      gen_tr.display("GEN");
      @(next);
    end
  ->done;
  endtask
endclass

class driver;
  transaction drv_tr;
  mailbox #(transaction) gen_drv;
  virtual inter inf;
  
  function new(mailbox #(transaction) gen_drv);
	this.gen_drv = gen_drv;
  endfunction
  
 
  task reset();
    @(posedge inf.clk);
    inf.rst_n <= 1'b0;
    repeat (5) @(negedge inf.clk);
    inf.rst_n <= 1'b1;
    $display("[DRV]: Reset done");
  endtask
  
  task main();
    forever begin
      gen_drv.get(drv_tr);
      @(negedge inf.clk);
       inf.wr_en <= drv_tr.wr_en;
       inf.rd_en <= drv_tr.rd_en;
       inf.wr_data <= drv_tr.wr_data;
      @(negedge inf.clk);
       inf.wr_en <= 1'b0;
       inf.rd_en <= 1'b0;
	drv_tr.display("DRV");
    end 
  endtask 
endclass


class monitor;
  transaction mon_tr;
  virtual inter inf;
  mailbox #(transaction) mon_sco;

	function new(mailbox #(transaction) mon_sco);
		mon_tr = new();
		this.mon_sco = mon_sco;
	endfunction
	
	task main();
	forever begin
      repeat (2) @(negedge inf.clk);
	   mon_tr.wr_en = inf.wr_en;
       mon_tr.rd_en = inf.rd_en;
       mon_tr.wr_data = inf.wr_data;
	   mon_tr.rd_data = inf.rd_data;
	   mon_tr.full = inf.full;
	   mon_tr.empty = inf.empty;
	   @(negedge inf.clk);
	   mon_sco.put(mon_tr);
	   mon_tr.display("MON");
	   end
	endtask

endclass



class scoreboard;
	transaction sco_tr;
	mailbox #(transaction) mon_sco;
	bit[31:0] que[$];
	bit [31:0] rd_chk;
  event next;
	
	
	function new(mailbox #(transaction) mon_sco);
		this.mon_sco = mon_sco;
	endfunction
	
	int error = 0;
	
	task main();
		forever begin
			mon_sco.get(sco_tr);
			sco_tr.display("SCO");
			
			
			if (sco_tr.rd_en) begin
              if(!sco_tr.empty || sco_tr.rd_data != 'b0) begin
					rd_chk = que.pop_back();
					
					if (rd_chk == sco_tr.rd_data) begin
                      $display("POP data matched, Pop Data = %0d",rd_chk );
					end
					else begin
                      $display("POP data mismatched, que_Pop Data = %0d, fifo_pop data = %0d",rd_chk,sco_tr.rd_data );
                      error++;
					end
				end	
				else begin
				$display("FIFO EMPTY");
				end
			$display("------------------------------------------------------");
			end
			else if(sco_tr.wr_en) begin
				if (!sco_tr.full) begin
					que.push_front(sco_tr.wr_data);
					$display("[SCO]: Data stored in queue: %0d", sco_tr.wr_data);
				end
				else begin
					$display("FIFO FULL");
				end
			$display("------------------------------------------------------");
			end
		->next;	
		end
    endtask
endclass



class environment;
	generator gen;
	driver drv;
	monitor mon;
	scoreboard sco;
	
	mailbox #(transaction) mon_sco;
	mailbox #(transaction) gen_drv;

	virtual inter inf;
	
	event next;
	
  function new(virtual inter inf);
		mon_sco = new();
		gen_drv = new();
		
		gen = new(gen_drv);
		drv = new(gen_drv);
		mon = new(mon_sco);
		sco = new(mon_sco);
		this.inf = inf;
		drv.inf = this.inf;
		mon.inf = this.inf;
		next = sco.next;
		gen.next = next;
		
	endfunction
	
	task pre_test();
		drv.reset();
	endtask
	
	task test();
		fork
			gen.main();
			drv.main();
			sco.main();
			mon.main();
		join
	endtask
	
	task post_test();
		wait(gen.done.triggered);
      $display("ERROR COUNT = %0d", sco.error);
		$finish;
	endtask
	
	task main();
      pre_test();
		fork
			test();
			post_test();
		join
	
	endtask

endclass



module tb;
	environment env;

	inter inf();

  	fifo dut(.clk(inf.clk), .rst_n(inf.rst_n), .rd_en(inf.rd_en), .wr_en(inf.wr_en), .rd_data(inf.rd_data), .wr_data(inf.wr_data), .full(inf.full), .empty(inf.empty));
  
  //fifo dut(inf.clk, inf.rst_n, inf.rd_en, inf.wr_en, inf.rd_data, inf.wr_data, inf.full, inf.empty);

	initial begin
		inf.clk = 0;

		forever #10 inf.clk =~inf.clk;
	end

	initial begin

		env = new(inf);

		env.gen.count = 100;

		env.main();

	end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
endmodule
    
