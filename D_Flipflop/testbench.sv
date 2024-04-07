class transaction;
  rand bit din;
  bit dout;
  
  
  function void display(input string tag);
    $display("[%0s]: d_in =%0d, d_dout =%0d",tag,din,dout);
  endfunction
  
  
  function transaction copy();
    copy = new();
    copy.din = this.din;
    copy.dout = this.dout;   
  endfunction
  
endclass

/////////////////////////////////////////////////////////////////////

class generator;
  
  transaction gen_tr;
  mailbox #(transaction) gen_drv;
  mailbox #(transaction) gen_sco;
  event sconext;
  event done;
  int count;
  
  function new(mailbox #(transaction) gen_drv,mailbox #(transaction) gen_sco);
    gen_tr = new();
    this.gen_drv = gen_drv;
    this.gen_sco = gen_sco;
  endfunction
  
  
  task main();
    repeat (count) begin
      assert(gen_tr.randomize) else $display("[GEN]: Randomization Failed");
      gen_drv.put(gen_tr.copy);
      gen_sco.put(gen_tr.copy);
      gen_tr.display("GEN");
      @(sconext);
    end
    ->done;
  endtask
  
endclass

//////////////////////////////////////////////////////////////////////


class driver;
  transaction drv_trans;
  virtual interf_dff dif;
  
  mailbox #(transaction) gen_drv;
  
  function new(mailbox #(transaction) gen_drv);
    this.gen_drv = gen_drv;
    endfunction
  
  task main();
    forever begin
      gen_drv.get(drv_trans);
      dif.din <= drv_trans.din;
      @(posedge dif.clk)
      drv_trans.display("DRV");
    end
  endtask
  
  
  task reset();
    dif.rst_n = 1'b0;
    repeat (5) @(posedge dif.clk);
    dif.rst_n = 1'b1;
    $display("[DRV]: Reset done");
  endtask
  
endclass


/////////////////////////////////////////////////////////////////////////

class monitor;
  transaction mon_tr;
  virtual interf_dff dif;
  
  mailbox #(transaction) mon_sco;
  
  function new(mailbox #(transaction) mon_sco);
    mon_tr = new();
    this.mon_sco = mon_sco;
  endfunction
  
  task main();
    forever begin
      repeat (2) @(posedge dif.clk)
    mon_tr.dout = dif.dout;
      mon_tr.display("MON");
      mon_sco.put(mon_tr);
      end
  endtask
  
endclass


////////////////////////////////////////////////////////////////////////



class scoreboard;
  transaction sco_tr;
  transaction sco_gen_tr;
  mailbox #(transaction) mon_sco;
  mailbox #(transaction) gen_sco;
  
  event sconext;
  
  
  function new(mailbox #(transaction) mon_sco, mailbox #(transaction) gen_sco);
    this.mon_sco = mon_sco;
    this.gen_sco = gen_sco;
  endfunction
  
  task main();
    forever begin
      mon_sco.get(sco_tr);
      gen_sco.get(sco_gen_tr);
      sco_tr.display("SCO");
      sco_gen_tr.display("MON_SCO");
      
      if(sco_gen_tr.din == sco_tr.dout) begin
        $display("DATA MATCHED"); end
      else begin
        $display("DATA MISMATCHED"); end
      
      $display("------------------------------------------------");
      -> sconext;
    end
  endtask
      
endclass


class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  event sconext;
  
  
  mailbox #(transaction) gen_drv, gen_sco, mon_sco;
  virtual interf_dff dif;
  
  function new(virtual interf_dff dif);
    gen_drv = new();
    gen_sco = new();
    mon_sco = new();
    gen = new(gen_drv, gen_sco);
    drv = new(gen_drv);
    mon = new(mon_sco);
    sco = new(mon_sco, gen_sco);
    this.dif = dif;
    drv.dif = this.dif;
    mon.dif = this.dif;
    sco.sconext = this.sconext;
    gen.sconext = this.sconext;
  endfunction
    
    
    task pre_test();
      drv.reset();
    endtask
    
    
    task test();
      fork 
        gen.main();
        drv.main();
        mon.main();
        sco.main();
      join
      
    endtask
    
    
    task post_test();
      wait(gen.done.triggered);
      $finish(); 
    endtask
    
    
    
    task main();
        pre_test();
      fork
        test();
        post_test();
      join
    endtask
  
endclass
    
 
module test;
    
  environment env;
  interf_dff dif();
      
  dff dut(dif);
     
  initial begin
    dif.clk <= 0;  
  end
          
  always #10 dif.clk = ~dif.clk;
       
  initial begin
    env = new(dif);
    env.gen.count = 15;
    env.main();    
  end
          
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars; 
   // #500 $finish;
  end
      
endmodule
