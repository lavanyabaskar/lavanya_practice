`ifndef APB_SEQUENCE_ITEM_SV
`define APB_SEQUENCE_ITEM_SV

class apb_sequence_item extends uvm_sequence_item;
  // APB transaction fields
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  rand bit        sel;

  // Constructor
  function new(string name = "apb_sequence_item");
    super.new(name);
  endfunction

  // UVM automation macros
  `uvm_object_utils_begin(apb_sequence_item)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(write, UVM_ALL_ON)
    `uvm_field_int(sel, UVM_ALL_ON)
  `uvm_object_utils_end

endclass : apb_sequence_item

`endif // APB_SEQUENCE_ITEM_SV

`endif // APB_SEQUENCE_ITEM_SV