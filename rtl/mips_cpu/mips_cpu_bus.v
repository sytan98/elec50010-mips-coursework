module mips_cpu_bus(
    /* Standard signals */
    input logic clk,
    input logic reset,
    output logic active,
    output logic[31:0] register_v0,

    /* Avalon memory mapped bus controller (master) */
    output logic[31:0] address,
    output logic write,
    output logic read,
    input logic waitrequest,
    output logic[31:0] writedata,
    output logic[3:0] byteenable,
    input logic[31:0] readdata
);
// cpu state
typedef enum logic[2:0] {
        FETCH = 3'b000,
        MEM = 3'b001,
        EXEC = 3'b010,
        HALTED = 3'b011,
        LOAD = 3'b100
} state_t;
logic[2:0] state;

// Wire Definition
logic       clk_enable;
// PC related
logic[31:0] pcin, pcout, pc_plus4, jump_addr, branch_addr, tgt_addr_0, tgt_addr_1;
logic       condition_met;
logic       delay;
// control signals
logic[1:0] rd_select;
logic      imdt_sel, branch, jump, jumpreg, alu_src, reg_write_enable, hi_wren, lo_wren, link_to_reg, mfhi, mflo, multdiv, lwl, lwr;
logic[2:0] datamem_to_reg;
logic[1:0] alu_op;
// register_file related
logic[4:0]  write_reg_rd;
logic[31:0] read_data_a, read_data_b, reg_write_data;
// reg_hi, reg_lo
logic[31:0] hi_readdata;
logic[31:0] lo_readdata;
// alu related
logic[31:0] signed_32, zero_32, immdt_32;
logic[4:0]  alu_ctrl_in;
logic[31:0] alu_in, alu_out, lo, hi;
logic       zero;

// bus related
logic[31:0] ir_readdata;
logic[31:0] instruction;
// assign instruction = ( ( (state==FETCH) & (waitrequest==1) ) | ( (state==MEM) & (waitrequest==0) ) ) ? readdata : ir_readdata;
// assign instruction = (state==MEM) ? readdata : ir_readdata;
assign instruction = ir_readdata;

// to ensure that the memory address is output from the CPU into bus_memory.v during MEM stage, important for load/store instructions
logic address_sel;
assign address_sel = (state==MEM) ? 1 : 0;

logic[31:0] memory_address;
logic[31:0] memory_address_temp;
logic[1:0]  byte_addressing;
logic [4:0] write_data_sel;

assign memory_address_temp = alu_out;                         // alu_out calculates address in memory based on read_data_a and immediate
assign memory_address = {memory_address_temp[31:2], 2'b00};   // to ensure that word output from memory is always word aligned
assign byte_addressing = memory_address_temp[1:0];            // last 2 LSB of memory address

initial begin
    state = HALTED;
    active = 0;
    delay = 0;
    clk_enable = 0;
end

always @(posedge clk) begin
    $display("-------------------------------");
    if (reset) begin
        $display("CPU : INFO  : Resetting.");
        state <= FETCH;
        active <= 1;
    end
    else if (state == FETCH) begin
        $display("CPU : INFO  : Fetching.");
        $display("current PC address =%h", pcout);
        if (waitrequest == 0) begin
          state <= LOAD;
        end
    end
    else if (state == LOAD) begin
      state <= MEM;

    end
    else if (state == MEM) begin
      if (waitrequest == 0) begin
          state <= EXEC;
          clk_enable <= 1;
        end
    end
    else if (state == EXEC) begin
        $display("CPU : INFO  : Executing.");
        //Current address
        $display("current PC address =%h", pcout);
        $display("current inst address =%h", address);
        $display("current inst =%h", readdata);

        //Branch/Jump Related
        $display("opcode = %d", readdata[31:26]);
        $display("branch = %h", branch);
        $display("jump = %h", jump);
        $display("jumpreg = %h", jumpreg);
        $display("condition_met = %h", condition_met);
        $display("tgt_addr_0 = %h", tgt_addr_0);
        $display("tgt_addr_1 = %h", tgt_addr_1);
        $display("delay = %h", delay);
        $display("branch address = %h", branch_addr);
        $display("jump address = %h", jump_addr);

        //Register Related
        $display("Reading Register A = %d", readdata[25:21]);
        $display("Reading Register B = %d", readdata[20:16]);
        $display("Data from Reg A = %h", read_data_a);
        $display("Data from Reg B = %h", read_data_b);
        $display("Register being written to = %d", write_reg_rd);
        $display("Reg Write Data = %h", reg_write_data);
        $display("Datamem to Reg signal for loads = %d", datamem_to_reg);
        $display("Link to reg for links = %d", link_to_reg);
        $display("Reg Write Enable = %h", reg_write_enable);

        //Data Memory Related
        $display("Data address = %h", memory_address);
        $display("Data address temp = %h", memory_address_temp);
        // $display("lwl signal = %b", lwl);
        // $display("lwr signal = %b", lwr);
        // $display("byte_addressing = %b", byte_addressing);
        // $display("data_readdata = %h", data_readdata);
        // $display("data read signal = %h", data_read);
        // $display("data write signal = %h", data_write);
        // $display("Write Data to data mem = %h", writedata);

        $display("immediate = %h", immdt_32);

        //ALU
        $display("alu_src = %b", alu_src);
        $display("alu out = %h", alu_out);
        // $display("value going into hi = %h", hi);
        // $display("value going into lo = %h", lo);

        if (address == 0) begin
            state <= HALTED;
            active <= 0;
        end
        else begin
          state <= FETCH;
        clk_enable <= 0;
        end
        if (branch|jump|jumpreg) begin
            delay <= 1;
        end
        else begin
            delay <= 0;
        end
    end
    else if (state == HALTED) begin
        //do nothing
        //potential bug, still increments pc?
    end
end

//IR
instr_register ir_inst(
  .clk(clk), .reset(reset), .waitrequest(waitrequest),
  .state(state), .ir_writedata(readdata),
  .ir_readdata(ir_readdata)
);

//PC
pc pc_inst(
  .clk(clk), .reset(reset),
  .clk_enable(clk_enable),
  .pcin(pcin),
  .pcout(pcout)
);

//PCadder
pc_adder pcadder_inst(
  .pcout(pcout),
  .pc_plus4(pc_plus4)
);

// control.v
control control_inst(
  .reset(reset), .opcode(instruction[31:26]), .function_code(instruction[5:0]), .b_code(instruction[20:16]),
  .state(state), .waitrequest(waitrequest), .byte_addressing(byte_addressing), .write_data_sel(write_data_sel),
  .rd_select(rd_select),
  .imdt_sel(imdt_sel),
  .branch(branch),
  .jump(jump),
  .jumpreg(jumpreg),
  .alu_op(alu_op),
  .alu_src(alu_src),
  .read(read),
  .write(write),
  .reg_write_enable(reg_write_enable),
  .hi_wren(hi_wren),
  .lo_wren(lo_wren),
  .datamem_to_reg(datamem_to_reg),
  .link_to_reg(link_to_reg),
  .mfhi(mfhi), .mflo(mflo), .multdiv(multdiv),
  .lwl(lwl), .lwr(lwr), .byteenable(byteenable)
);

destination_reg_selector rd_selector(
  .read_reg_b(instruction[20:16]),          // register rt, instruction[20:16]
  .rtype_rd(instruction[15:11]),            // register rd, instruction[15:11]
  .rd_select(rd_select),                    // from control.v, select signal to select destination register
  .write_reg_rd(write_reg_rd)               // destinatoin register, connected to register_file.v
);

//register_file
register_file regfile_inst(
  .clk(clk),
  .clk_enable(clk_enable),
  .reset(reset),
  .read_reg_a(instruction[25:21]), .read_reg_b(instruction[20:16]),
  .read_data_a(read_data_a), .read_data_b(read_data_b),
  .write_reg_rd(write_reg_rd),
  .reg_write_data(reg_write_data),
  .reg_write_enable(reg_write_enable),
  .register_v0(register_v0),
  .byte_addressing(byte_addressing), .lwl(lwl), .lwr(lwr)
);

//immdt_extender
immdt_extender imdtextd_inst(
  .immdt_16(instruction[15:0]),
  .sign_immdt_32(signed_32), .zero_immdt_32(zero_32)
);

//immdt mux
mux_32bit imdtmux(
  .select(imdt_sel),
  .in_0(signed_32), .in_1(zero_32),
  .out(immdt_32)
);

//alumux
mux_32bit alumux(
  .select(alu_src),
  .in_0(read_data_b), .in_1(immdt_32),
  .out(alu_in)
);

//memory address mux
mux_32bit addressmux(
  .select(address_sel),
  .in_0(pcout), .in_1(memory_address),
  .out(address)
);

//alu_ctrl
alu_ctrl aluctrl_inst(
  .alu_op(alu_op),
  .opcode(instruction[31:26]),
  .function_code(instruction[5:0]),
  .alu_ctrl_in(alu_ctrl_in)
);

//alu
alu alu_inst(
  .alu_ctrl_in(alu_ctrl_in),
  .A(read_data_a),
  .B(alu_in),
  .shamt(instruction[10:6]),
  .alu_out(alu_out),
  .zero(zero),
  .lo(lo),
  .hi(hi)
);

//reg_hi
reg_hi reghi_inst(
  .clk(clk), .reset(reset),
  .clk_enable(clk_enable),
  .hi_wren(hi_wren), .multdiv(multdiv),
  .read_data_a(read_data_a),
  .hi(hi),
  .hi_readdata(hi_readdata)
);

//reg_lo
reg_lo reglo_inst(
  .clk(clk), .reset(reset),
  .clk_enable(clk_enable),
  .lo_wren(lo_wren), .multdiv(multdiv),
  .read_data_a(read_data_a),
  .lo(lo),
  .lo_readdata(lo_readdata)
);

// branch_cond
branch_cond branchcond_inst(
  .branch(branch),
  .opcode(instruction[31:26]), .b_code(instruction[20:16]),
  .equal(zero),
  .read_data_a(read_data_a),
  .condition_met(condition_met)
);

//jump_addressor
jump_addressor j_calc(
  .j_immdt(instruction[25:0]),
  .pc_4msb(pc_plus4[31:28]),
  .jump_addr(jump_addr)
);

// branch_addressor
branch_addressor b_calc(
  .immdt_32(immdt_32),
  .pc_plus4(pc_plus4),
  .branch_addr(branch_addr)
);

//PC_address_selector -> Manages which target address to store into register
pc_address_selector pcsel_inst(
  .branch_addr(branch_addr),
  .jump_addr(jump_addr),
  .read_data_a(read_data_a),
  .pc_plus4(pc_plus4),
  .condition_met(condition_met), //from branch_cond block
  .jump(jump), //from control, for J and JAL
  .jumpreg(jumpreg), //from control, for JR and JALR
  .tgt_addr_0(tgt_addr_0)
);

//Register to hold target address from PC_address_selector
target_addr_holder taddr_inst(
  .clk(clk),
  .clk_enable(clk_enable),
  .tgt_addr_0(tgt_addr_0),
  .tgt_addr_1(tgt_addr_1)
);

//PC Mux to choose PC + 4 or target address
mux_32bit pcmux(
  .select(delay),
  .in_0(pc_plus4), .in_1(tgt_addr_1),
  .out(pcin)
);

reg_writedata_selector regwritedata_sel(
  .alu_out(alu_out), .data_readdata(readdata), .pc_plus4(pc_plus4),
  .hi_readdata(hi_readdata), .lo_readdata(lo_readdata),
  .datamem_to_reg(datamem_to_reg), .link_to_reg(link_to_reg),
  .mfhi(mfhi), .mflo(mflo), .byte_addressing(byte_addressing),
  .reg_write_data(reg_write_data)
);

writedata_selector writedata_sel(
  .read_data_b(read_data_b),
  .write_data_sel(write_data_sel),
  .writedata(writedata)
);

endmodule
