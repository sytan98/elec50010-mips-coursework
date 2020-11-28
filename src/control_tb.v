module control_tb(
);
    logic[5:0] opcode;
    logic[5:0] function_code;
    logic[4:0] b_code; //branch instruction code
    logic rd_select; //output - select register to write to
    logic branch; //output - if branch, go to 1 so that block can check if condition met
    logic jump1; //output - select between output and branch mux (JAL J)
    logic jump2; //output - select between output jump1 mux or read data a (JR JALR)
    logic[1:0] alu_op; //output //for alu control
    logic alu_src; //output //controls what is going into alu ()
    logic data_read; //output //High for load instructions 
    logic data_write; //output //High for store instructions
    logic write_enable; //output //High for writing reg file (Arithmetic, logical shifts, setting inst, loading)
    logic hi_wren; //output for writing to hi
    logic lo_wren; //output for writing to lo
    logic data_into_reg1; //output //
    logic data_into_reg2; //output //for anything and links

    initial begin
        //R Type
        opcode = 0;

        //addu
        #1;
        function_code = 33;
        #1;
        // $display("a=%d, b=%d, r=%d, time=%t", A, B, alu_out, $time);
        assert(rd_select == 1) else $fatal(1, "Addu does not select correct register to write");
        assert(alu_op == 2) else $fatal(1, "Addu does not send correct alu_op");
        assert(alu_src == 0) else $fatal(1, "Addu does not send correct alu port b input");
        assert(write_enable == 1)  else $fatal(1, "Addu cannot save data in reg file");
        #1

        //xor
        #1;
        function_code = 38;
        #1;
        // $display("a=%d, b=%d, r=%d, time=%t", A, B, alu_out, $time);
        assert(rd_select == 1) else $fatal(1, "Xor does not select correct register to write");
        assert(alu_op == 0) else $fatal(1, "Xor does not send correct alu_op");
        assert(alu_src == 1) else $fatal(1, "Xor does not send correct alu port b input");
        assert(write_enable == 1)  else $fatal(1, "Xor cannot save data in reg file");
        #1

        //sltu

        //Load/store

        //lw
        #1;
        function_code = 35;
        #1;
        // $display("a=%d, b=%d, r=%d, time=%t", A, B, alu_out, $time);
        assert(rd_select == 1) else $fatal(1, "Lw does not select correct register to write");
        assert(alu_op == ) else $fatal(1, "Xor does not send correct alu_op");
        assert(alu_src == ) else $fatal(1, "Xor does not send correct alu port b input");
        assert(write_enable == 1)  else $fatal(1, "Xor cannot save data in reg file");
        #1

        //sh
        #1;
        function_code = 38;
        #1;
        // $display("a=%d, b=%d, r=%d, time=%t", A, B, alu_out, $time);
        assert(rd_select == 1) else $fatal(1, "Xor does not select correct register to write");
        assert(alu_op == 2) else $fatal(1, "Xor does not send correct alu_op");
        assert(alu_src == 0) else $fatal(1, "Xor does not send correct alu port b input");
        assert(write_enable == 1)  else $fatal(1, "Xor cannot save data in reg file");
        #1
        //lwr

        //mtlo

        //lui

        //Jump Type

        //Jump

        //JALR

        //JR

        //Branch Type
        //BEQ

        //BTLZAL

        $display("Finished. Total time = %t", $time);
        $finish;
    end

    control dut(
        .opcode(opcode),
        .function_code,
        .b_code(b_code),
        .rd_select(rd_select),
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

endmodule
