module bus_memory(
	input logic clk,
	input logic[31:0] address,
	input logic write,
    input logic read,
    output logic waitrequest,
    input logic[31:0] writedata,
    input logic[3:0] byteenable,
    output logic[31:0] readdata
);
	// Memory (256 x 4 x 8-bit bytes) address is 32 bits (used only 10), word is 32 bits
	// Full memory supposed to be able to store 2^30 words but we reduce it to store 2^8 (256) words. 
	// 10 bits used for address as it is byte addressing.
	parameter ROM_INIT_FILE = "";
	parameter RAM_INIT_FILE = "";
	parameter address_bit_size = 10; 
	parameter reset_vector = 128; // this is word addressing, technically should be 0xbfc00000 
	// instructions start at word 128
	// this divides memory equally between data(first half excluding address 0) and instructions (second half starting at word 128)


	// If address > BFC00000, it is instruction address and needs to be mapped to start at word 128
	// otherwise, it is a data address (keep the same)

	logic[address_bit_size - 1: 0] mapped_address;		

	assign mapped_instr_address = (address >=32'hBFC00000) ? address[address_bit_size-1:0] - 32'hBFC00000+32'h00000080 : address[address_bit_size-1:0];


	// Update readdata - only available one cycle after read request

	logic[7:0] bytes [0: (2**address_bit_size-1)];
	
 	// Stall stores the value of waitrequest
 	logic stall = 0;
 	assign waitrequest = stall;

  	//write writedata to mapped_address word
	always_ff @(posedge clk) begin
		if (stall==0 && (write==1 || read==1)) begin // if read/write are asserted, start waitrequest
			stall<=1;
		end
    	if (write == 1 && stall==1) begin // write
    		if (byteenable[0]==1)
      		bytes[mapped_address] <= writedata[7:0] & byteenable[0]; 
      		bytes[mapped_address+1] <= writedata[15:8] & byteenable[1];
      		bytes[mapped_address+2] <= writedata[23:16] & byteenable[2];
      		bytes[mapped_address+3] <= writedata[31:24] & byteenable[3];
      		stall<=0;
    	end
    	if (read == 1 && stall==1) begin // read
      		readdata <= {bytes[mapped_instr_address+3], bytes[mapped_instr_address+2], bytes[mapped_instr_address+1], bytes[mapped_instr_address]};
      		stall<=0;
    	end
  	end

  	//Initialise memory:

	initial begin
		if (ROM_INIT_FILE != "") begin // instruction memory
			$readmemh(ROM_INIT_FILE, bytes, reset_vector*4); // multiply by 4 to get byte addressing
		end
		if (RAM_INIT_FILE != "") begin
      		$readmemh(RAM_INIT_FILE, bytes, 4); // data memory - don't write to address 0
    	end
	end

	
endmodule