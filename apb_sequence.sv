`ifndef APB_SEQUENCE_SV
`define APB_SEQUENCE_SV

class apb_sequence extends uvm_sequence#(apb_sequence_item);
  // Constructor
  function new(string name = "apb_sequence");
    super.new(name);
  endfunction

  // UVM automation macro
  `uvm_object_utils(apb_sequence)

  // Sequence body
  virtual task body();
    apb_sequence_item req;

    // Create and randomize sequence item
    req = apb_sequence_item::type_id::create("req");
    start_item(req);
    if (!req.randomize()) begin
      `uvm_error(get_type_name(), "Randomization failed")
    end
    finish_item(req);
  endtask : body

endclass : apb_sequence

`endif // APB_SEQUENCE_SV