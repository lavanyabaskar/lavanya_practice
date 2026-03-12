// Code your testbench here
// or browse Examples
//typedef enum {READ, WRITE} apb_op_e;


class apb_item extends uvm_sequence_item;

  // 1. Transaction Fields
  rand logic [31:0] paddr;
  rand logic [31:0] pwdata;
  rand logic     pwrite;

  rand int          delay;  // 'int' is used here for randomization

  // 2. Response Fields (coming back from Slave)
  logic [31:0]      prdata;
  logic             pslverr;

  // 3. UVM Field Macros
  // These macros automate copy, compare, print, and pack
  `uvm_object_utils_begin(apb_item)
    `uvm_field_int(paddr,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(pwdata,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int( pwrite, UVM_ALL_ON)
    `uvm_field_int(delay,   UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(prdata,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(pslverr, UVM_ALL_ON | UVM_BIN)
  `uvm_object_utils_end

  // Constructor
  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  // Optional: Custom constraints
  constraint c_addr { paddr[1:0] == 0; } // Word aligned
  constraint c_delay { delay inside {[0:5]}; }

endclass


//`include "apb_seq_item.sv" // Ensure your class file is included

//module tb_top;

//apb_seq_item item1;
// apb_seq_item item2;

  //initial begin
    // 1. Create instances using the UVM Factory
    /*item1 = apb_seq_item::type_id::create("item1");
    item2 = apb_seq_item::type_id::create("item2");

    $display("\n--- Step 1: Randomizing Item 1 ---");
    if (!item1.randomize()) `uvm_error("RAND", "Randomization failed")
    
    // 2. View the working of `print()` (provided by uvm_field macros)
    item1.print();

    $display("\n--- Step 2: Testing copy() ---");
    // Copy item1's randomized values into item2
    item2.copy(item1);
    
    if (item2.paddr == item1.paddr) 
      $display("Copy Successful! Addr: %0h", item2.paddr);
    else 
      $display("Copy Failed!");

    $display("\n--- Step 3: Testing compare() ---");
    // Initially, they should match
    if (item1.compare(item2))
      $display("Compare: Items Match!");
    else
      $display("Compare: Items Mismatch!");

    // Manually change a value to force a mismatch
    item2.paddr = item2.paddr + 1;
    $display("Changed Item 2 Addr to %0h", item2.paddr);

    if (item1.compare(item2))
      $display("Compare: Items Match!");
    else
      $display("Compare: Items Mismatch (Correct!)");

    $display("\n--- Step 4: Final View ---");
    item2.print();
    
  end
endmodule*/
class apb_master_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_master_seq)

  function new(string name = "apb_master_seq");
    super.new(name);
  endfunction

  virtual task body();
    // 1. Create the item using the factory
    req = apb_item::type_id::create("req");

    // 2. start_item: Blocks until the sequencer grants access.
    // This is the "Request" phase.
    start_item(req);

    // 3. Late Randomization: 
    // It is best practice to randomize AFTER start_item returns.
    // This ensures your constraints use the most up-to-date state of the TB.
    if (!req.randomize() with { paddr inside {[32'h0 : 32'hFFF]}; }) begin
      `uvm_error("SEQ", "Randomization failed")
    end
    //`uvm_do(req);

    // 4. finish_item: Blocks until the Driver calls item_done().
    // This triggers the Driver to actually execute the transaction.
    finish_item(req);
    req.print();
    // 5. (Optional) Get Response:
    // If your driver sends a response (like Read Data)
    // get_response(rsp); 
  endtask
endclass

class apb_burst_seq extends uvm_sequence#(apb_item);
  `uvm_object_utils(apb_burst_seq)
  apb_item req;
  int num_txns;
  function new (string name="apb_burst_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    req=apb_item::type_id::create("req");
    if (!uvm_config_db#(int)::get(m_sequencer, "", "num_txns", num_txns)) begin
      `uvm_fatal("SEQ", "Could not get number of transactions handle")
    end
    repeat(num_txns) begin
    //  start_item(req);
      `uvm_do(req);
      req.print();
      //finish_item(req);
    end
  endtask
endclass
  

class apb_sequencer extends uvm_sequencer#(apb_item);
  `uvm_component_utils(apb_sequencer);
  function new (string name ="apb_sequencer",uvm_component parent);
    super.new(name,parent);
  endfunction
endclass

//DRIVER

class apb_driver extends uvm_driver #(apb_item);
  `uvm_component_utils(apb_driver)
  apb_item item;
  // Virtual Interface to drive pins
  virtual apb_if vif;
  int num_txns;
  int i;

  // Constructor (Two arguments for components!)
  function new(string name="abp_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  // Build Phase: Get the interface from config_db
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    $display(" driver build phase");
    item = apb_item::type_id::create("req");
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("DRV", "Could not get vif handle")
    end
    if (!uvm_config_db#(int)::get(this, "", "num_txns", num_txns)) begin
      `uvm_fatal("DRV", "Could not get number of transactions handle")
    end
  endfunction

  // Run Phase: The main loop
  virtual task run_phase(uvm_phase phase);
    // Initialize signals
    vif.psel    <= 0;
    vif.penable <= 0;
    $display(" driver run phase");
    forever begin
      // 1. Get the next item from the sequencer
      seq_item_port.get_next_item(item);

      // 2. Execute the transaction on the bus
      drive_transfer(item);

      // 3. Tell the sequencer we are done
      seq_item_port.item_done();
    end
  endtask

  // Logic to drive APB protocol
  virtual task drive_transfer(apb_item item);
    $display("DRV : waiting for clk");
    @(posedge vif.pclk);
    i++;
    $display("txn no: %0d",i);
    item.print();
    // Setup Phase
    vif.paddr   <= item.paddr;
    vif.pwrite  <= item.pwrite; // 1 for Write, 0 for Read
    vif.psel    <= 1;
    if (item.pwrite== 1) vif.pwdata <= item.pwdata;

    @(posedge vif.pclk);
    
    // Access Phase
    vif.penable <= 1;

    // Wait for Slave to be ready (APB3/4)
    wait(vif.pready == 1);
    
    // Capture data if it's a Read
    if (item.pwrite== 0) item.prdata = vif.prdata;

    @(posedge vif.pclk);
    vif.penable   <= 0;
    if(i==num_txns)
    vif.psel <= 0;
  endtask

endclass



class apb_monitor extends uvm_monitor;
  apb_item req;
  `uvm_component_utils(apb_monitor)

  // Virtual Interface to drive pins
  virtual apb_if vif;
  uvm_analysis_port #(apb_item) item_collected_port;
  // Constructor (Two argus for components!)
  function new(string name="apb_monitor", uvm_component parent);
    super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
  endfunction

  // Build Phase: Get the interface from config_db
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    $display(" mon build phase");
    req = apb_item::type_id::create("req");
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("MON", "Could not get vif handle")
    end
  endfunction

  // Run Phase: The main loop
  virtual task run_phase(uvm_phase phase);
    $display(" mon run phase");
    forever begin
    
    @(posedge vif.pclk);
    $display("MON waiting clk");
    // Setup Phase
    if(vif.psel===1 && vif.penable===1&& vif.pready ===1) begin
    req.paddr<=vif.paddr;
    req.pwrite<=vif.pwrite ; // 1 for Write, 0 for Read
      if(req.pwrite ==1) req.pwdata <= vif.pwdata;
      else
    	req.prdata <= vif.prdata;
    
      `uvm_info(get_type_name(), $sformatf("Collected: "), UVM_LOW)
      $display("MON");
      req.print();
    // 5. Broadcast the item to the Analysis Port
      item_collected_port.write(req);
    // Capture data if it's a Read
    end
    end
  endtask

endclass
  
class apb_agent extends uvm_agent;
      `uvm_component_utils(apb_agent)
      
      apb_driver drv;
      apb_monitor mon;
      uvm_sequencer #(apb_item) seqr;
      
      function new (string name ="apb_agent",uvm_component parent);
       super.new(name, parent);
          endfunction 
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    $display(" agent build phase");
    drv=apb_driver ::type_id::create("drv", this);
    mon=apb_monitor ::type_id::create("mon", this);
    seqr=uvm_sequencer#(apb_item)::type_id:: create("seqr", this);
   endfunction 
      
      function void connect_phase(uvm_phase phase);
        $display(" agent connect phase");
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
      endfunction
    endclass
    
     
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  // Analysis imp to receive items from monitor
  uvm_analysis_imp #(apb_item, apb_scoreboard) ap_imp;

  // Optional verbosity knob
  uvm_verbosity m_verb = UVM_LOW;

  function new(string name = "apb_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Construct analysis imp here (safer if you later add config-based naming)
    ap_imp = new("ap_imp", this);
  endfunction

  // The monitor will call write() via the imp
  function void write(apb_item t);
    `uvm_info("SB",
      $sformatf("PADDR=%08h PWRITE=%0d PWDATA=%08h PRDATA=%08h PSLVERR=%0b",
                t.paddr, t.pwrite, t.pwdata, t.prdata, t.pslverr),
      m_verb)
  endfunction
endclass

    
    
    class apb_env extends uvm_env;
      `uvm_component_utils(apb_env)
      
       apb_agent agent;
      apb_scoreboard sb;
      
      function new (string name ="apb_env",uvm_component parent);
       super.new(name, parent);
       
        endfunction
      
     function void build_phase(uvm_phase phase);
      super.build_phase(phase);
       $display(" env build phase");
       agent=apb_agent ::type_id::create("agent", this);
       sb=apb_scoreboard ::type_id::create("sb", this);
       endfunction 
      
      function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        $display("env connect block");
        agent.mon.item_collected_port.connect(sb.ap_imp);
      endfunction
    endclass
    
    
    class apb_test extends uvm_test;
      `uvm_component_utils(apb_test)
      
      apb_env env;
      
      function new (string name ="apb_test",uvm_component parent);
       super.new(name, parent);
              endfunction
      
      function void build_phase(uvm_phase phase);
      super.build_phase(phase);
        $display(" test build phase");
        env=apb_env ::type_id::create("env", this);
       
       endfunction
      
      task run_phase(uvm_phase phase);
        apb_master_seq seq;
        seq=apb_master_seq::type_id::create("seq");
        phase.raise_objection(this);
         $display("test block");
        #100;
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
        
      endtask
    endclass
    
  
class apb_burst_test extends apb_test;
  `uvm_component_utils(apb_burst_test)

  function new (string name="apb_burst_test", uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(int)::set(null, "*", "num_txns", 5);
  endfunction

  task run_phase(uvm_phase phase);
    apb_burst_seq seq1;

    phase.raise_objection(this);
    #100ns;

    seq1 = apb_burst_seq::type_id::create("seq1");
    seq1.start(env.agent.seqr);  // reuse env from apb_test

    phase.phase_done.set_drain_time(this, 100ns);
    phase.drop_objection(this);
  endtask
endclass

   interface apb_if (input pclk);
  logic PRESET;
  logic[31:0] paddr;
  logic[31:0] pwdata;
  logic[31:0] prdata;
  logic pwrite,psel,penable,pslverr,pready;
endinterface
      
     
    
module top;

  // -----------------------------------------
  // Clock
  // -----------------------------------------
  bit PCLK = 0;
  always #5 PCLK = ~PCLK;  // 100 MHz

  // -----------------------------------------
  // APB interface instance
  // -----------------------------------------
  apb_if vif(PCLK);

  // -----------------------------------------
  // Proper reset sequencing
  //   - apb_if has active-high PRESET
  //   - DUT has active-low PRESETn (we invert)
  // -----------------------------------------
  initial begin
    // Assert reset
    vif.PRESET  = 1'b1;   // => PRESETn=0 (in reset)
    // Initialize bus
    vif.psel    = 1'b0;
    vif.penable = 1'b0;
    vif.pwrite  = 1'b0;
    vif.paddr   = '0;
    vif.pwdata  = '0;
    // Hold reset for a few cycles
    repeat (4) @(posedge PCLK);
    // Deassert reset
    vif.PRESET  = 1'b0;   // => PRESETn=1 (out of reset)
  end

  // -----------------------------------------
  // DUT instance (APB3 slave)
  // -----------------------------------------
  apb_slave #(
    .ADDR_WIDTH(8),
    .DATA_WIDTH(32),
    .NUM_REGS  (16)
  ) dut (
    .PCLK   (vif.pclk),
    .PRESETn(~vif.PRESET),   // invert active-high interface reset
    .PSEL   (vif.psel),
    .PENABLE(vif.penable),
    .PWRITE (vif.pwrite),
    .PADDR  (vif.paddr),
    .PWDATA (vif.pwdata),
    .PRDATA (vif.prdata),
    .PREADY (vif.pready),
    .PSLVERR(vif.pslverr)
  );

  // -----------------------------------------
  // VCD dump (must be enabled BEFORE run_test)
  // -----------------------------------------
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, top);
  end

  // -----------------------------------------
  // Hand off VIF and start UVM
  // -----------------------------------------
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", vif);
    run_test("apb_burst_test");  // or: run_test() + +UVM_TESTNAME=apb_burst_test
  end
   
endmodule
      
   
