module mem_alignment(input logic [31:0] raw_word,store_data,input logic [1:0] offset,input logic [2:0] funct3,output logic [31:0] load_data,aligned_store_data,output logic [3:0] wsel);
 logic [31:0] shifted;
 always_comb begin
  shifted=raw_word>>(8*offset);
  case(funct3)
   3'b000: load_data={{24{shifted[7]}},shifted[7:0]};
   3'b001: load_data={{16{shifted[15]}},shifted[15:0]};
   3'b010: load_data=raw_word;
   3'b100: load_data={24'b0,shifted[7:0]};
   3'b101: load_data={16'b0,shifted[15:0]};
   default: load_data=0;
  endcase
  aligned_store_data=store_data << (8*offset);
  case(funct3)
   3'b000: wsel=4'b0001<<offset;
   3'b001: wsel=4'b0011<<offset;
   3'b010: wsel=4'b1111;
   default: wsel=0;
  endcase
  if ((funct3==3'b001 && offset[0]) || (funct3==3'b010 && offset!=0)) wsel=0;
 end
endmodule
