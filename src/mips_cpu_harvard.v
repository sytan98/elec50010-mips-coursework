module mips_cpu_harvard(
    /* Standard signals */
    input logic     clk,
    input logic     reset,
    output logic    active,
    output logic [31:0] register_v0,

    /* New clock enable. See below. */
    input logic     clk_enable,

    /* Combinatorial read access to instructions */
    output logic[31:0]  instr_address,
    input logic[31:0]   instr_readdata,

    /* Combinatorial read and single-cycle write access to instructions */
    output logic[31:0]  data_address,
    output logic        data_write,
    output logic        data_read,
    output logic[31:0]  data_writedata,
    input logic[31:0]  data_readdata,
    output logic[1:0] check_state, //for debugging
    output logic[31:0] check_pcout //for debugging
);

//cpu state
typedef enum logic[1:0] {
        FETCH = 2'b00,
        EXEC = 2'b01,
        DELAY = 2'b10,
        HALTED = 2'b11
} state_t;
logic[1:0] state;

//Wire Definition
logic[31:0] pcin;
logic[31:0] pcout;
logic[31:0] pc_plus4;
logic rd_select, imdt_sel, branch, jump1, jump2, alu_src, write_enable, hi_wren, lo_wren, data_into_reg1, data_into_reg2;
logic[1:0] alu_op;
logic[4:0] write_reg_rd;
logic[31:0] read_data_a, read_data_b, write_data;
logic[31:0] signed_32, zero_32;
logic[31:0] immdt_32;
logic[31:0] alu_in;
logic[5:0] alu_ctrl_in;
logic[31:0] alu_out, lo, hi;
logic zero;

logic[31:0] hi_read;
logic[31:0] lo_read;
logic condition_met;
logic[31:0] jump_addr;
logic[31:0] branch_addr;
logic[31:0] bmuxout;
logic[31:0] jmuxout;

logic[31:0] data1muxout;
logic delay;

assign check_state = state; //for debugging
assign check_pcout = pcout; //for debugging
assign instr_address = pcout;

initial begin
    state = HALTED;
    active = 0;
end

always @(posedge clk) begin
    if (reset) begin
        $display("CPU : INFO  : Resetting.");
        state <= EXEC;
        active <= 1;
    end
    else if (state == EXEC) begin
        $display("CPU : INFO  : Executing.");
        $display("current PC address=%d", pcout);
        $display("current inst address=%d", instr_address);
        $display("current inst =%h", instr_readdata);
        $display("alu src =%h", alu_src);
        $display("alu op =%h", alu_op);
        $display("imd sel =%h", imdt_sel);
        $display("Read Data Address A=%d", instr_readdata[25:21]);
        $display("Read Data Address B=%d", instr_readdata[20:16]);
        $display("Write Data Address=%d", write_reg_rd);
        $display("Write Data=%h", write_data);
        $display("Data from A=%h", read_data_a);
        $display("Data from B=%h", read_data_b);
        if (instr_address[15:0] == 0) begin
            state <= HALTED;
            active <= 0;
        end
        if (instr_address[]) begin
            state <= DELAY;
            delay <= 1;
        end
    end
    else if (state == DELAY) begin
        state <= EXEC;
    end
    else if (state == HALTED) begin
        //do nothing
        //potential bug, still increments pc?
    end
end


//PC
pc pc_inst(
  .clk(clk), .reset(reset),
  .pcin(pcin),
  .pcout(pcout)
);

//PCadder
pc_adder pcadder_inst(
  .pcout(pcout),
  .pc_plus4(pc_plus4)
);

//instruction_memory
// instruction_memory instmem_inst(
//   .clk(clk),
//   .instr_address(instr_address),
//   .instr_readdata(instr_readdata),
//   .clk_enable(clk_enable)
// );

// control
control control_inst(
  .opcode(instr_readdata[31:26]), .function_code(instr_readdata[5:0]), .b_code(instr_readdata[15:11]),
  .rd_select(rd_select),
  .imdt_sel(imdt_sel),
  .branch(branch),
  .jump1(jump1),
  .jump2(jump2),
  .alu_op(alu_op),
  .alu_src(alu_src),
  .data_read(data_read),
  .data_write(data_write),
  .write_enable(write_enable),
  .hi_wren(hi_wren),
  .lo_wren(lo_wren),
  .data_into_reg1(data_into_reg1),
  .data_into_reg2(data_into_reg2)
);

//mux_5bit rd_mux
mux_5bit rd_mux(
  .select(rd_select),
  .in_0(instr_readdata[20:16]), .in_1(instr_readdata[15:11]),
  .out(write_reg_rd)
);

//register_file
register_file regfile_inst(
  .clk(clk),
  .clk_enable(clk_enable),
  .reset(reset),
  .read_reg_a(instr_readdata[25:21]), .read_reg_b(instr_readdata[20:16]),
  .read_data_a(read_data_a), .read_data_b(read_data_b),
  .write_reg_rd(write_reg_rd),
  .write_data(write_data),
  .write_enable(write_enable),
  .register_v0(register_v0)
);

//immdt_extender
immdt_extender imdtextd_inst(
  .immdt_16(instr_readdata[15:0]),
  .sign_immdt_32(signed_32), .zero_immdt_32(zero_32)
);

//immdt mux
mux_32bit imdtmux(
  .select(imdt_sel),
  .in_0(signed_32), .in_1(zero_32),
  .out(immdt_32)
);

//mux_32bit alumux
mux_32bit alumux(
  .select(alu_src),
  .in_0(read_data_b), .in_1(immdt_32),
  .out(alu_in)
);

//alu_ctrl
alu_ctrl aluctrl_inst(
  .alu_op(alu_op),
  .opcode(instr_readdata[31:26]),
  .function_code(instr_readdata[5:0]),
  .alu_ctrl_in(alu_ctrl_in)
);

//alu
alu alu_inst(
  .alu_ctrl_in(alu_ctrl_in),
  .A(read_data_a),
  .B(alu_in),
  .shamt(instr_readdata[10:6]),
  .alu_out(alu_out),
  .zero(zero),
  .lo(lo),
  .hi(hi)
);

//reg_hi
reg_hi reghi_inst(
  .clk(clk), .reset(reset),
  .hi_wren(hi_wren),
  .read_data_a(read_data_a),
  .hi(hi),
  .hi_read(hi_read)
);

//reg_lo
reg_lo reglo_inst(
  .clk(clk), .reset(reset),
  .lo_wren(lo_wren),
  .read_data_a(read_data_a),
  .lo(lo),
  .lo_read(lo_read)
);

// branch_cond
branch_cond branchcond_inst(
  .branch(branch),
  .opcode(instr_readdata[31:26]), .b_code(instr_readdata[15:11]),
  .equal(zero),
  .read_data_a(read_data_a),
  .condition_met(condition_met)
);

//jump_addressor
jump_addressor j_calc(
  .j_immdt(instr_readdata[25:0]),
  .pc_4msb(pc_plus4[31:28]),
  .jump_addr(jump_addr)
);

// branch_addressor
branch_addressor b_calc(
  .immdt_32(immdt_32),
  .PCnext(pc_plus4),
  .branch_addr(branch_addr)
);

//mux_32bit branchmux
mux_32bit branchmux(
  .select(condition_met),
  .in_0(pc_plus4), .in_1(branch_addr),
  .out(bmuxout)
);
//mux_32bit jump1mux
mux_32bit jump1mux(
  .select(jump1),
  .in_0(bmuxout), .in_1(jump_addr),
  .out(jmuxout)
);
//mux_32bit jump2mux
mux_32bit jump2mux(
  .select(jump2),
  .in_0(jmuxout), .in_1(read_data_a),
  .out(pcin)
);

// //data_memory
// // data_memory datamem_inst(
// //   .clk(clk),
// //   .data_address(data_address),
// //   .data_read(data_read),
// //   .data_write(data_write),
// //   .data_writedata(data_writedata),
// //   .data_readdata(data_readdata),
// //   .clk_enable(clk_enable)
// // );

//data_into_reg_mux1
mux_32bit data1mux(
  .select(data_into_reg1),
  .in_0(alu_out), .in_1(data_readdata),
  .out(data1muxout)
);

//data_into_reg_mux2
mux_32bit data2mux(
  .select(data_into_reg2),
  .in_0(data1muxout), .in_1(pc_plus4),
  .out(write_data)
);

endmodule
