module rv32i_soc_top (
    input logic clk,
    input logic reset
);
    logic [31:0] pc, instruction, inst_from_mem;
    logic [6:0]  opcode, funct7;
    logic [2:0]  funct3;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] rs1_data, rs2_data, immediate, alu_result, wb_data;
    logic        branch_taken, redirect;
    logic [31:0] redirect_target;

    logic        mem_read, mem_write, rf_we;
    logic [1:0]  memtoreg;

    always_comb begin
        mem_read  = (opcode == 7'h03);
        mem_write = (opcode == 7'h23);
        rf_we     = 1'b0;
        memtoreg  = 2'b00;
        case (opcode)
            7'h33, 7'h13: rf_we = 1'b1;
            7'h03: begin rf_we = 1'b1; memtoreg = 2'b01; end
            7'h6f, 7'h67, 7'h37, 7'h17: begin rf_we = 1'b1; memtoreg = 2'b10; end
            default: ;
        endcase
    end

    logic [31:0] mem_address, mem_write_data, mem_read_data, load_data;
    logic [3:0]  byte_we;
    logic        mem_read_en, access_valid;

    rv32i_inst_memory u_imem (.address(pc), .instruction(inst_from_mem));

    rv32i_if_id_ex u_core (
        .clk(clk), .reset(reset),
        .instruction_in(inst_from_mem),
        .rf_external_we(rf_we),
        .rf_external_waddr(rd),
        .mem_out(load_data),
        .memtoreg(memtoreg),
        .pc(pc), .instruction(instruction),
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .immediate(immediate), .alu_result(alu_result),
        .wb_data(wb_data), .branch_taken(branch_taken),
        .redirect(redirect), .redirect_target(redirect_target)
    );

    rv32i_mem_stage u_mem_stage (
        .address(alu_result), .store_data(rs2_data),
        .funct3(funct3), .mem_read(mem_read), .mem_write(mem_write),
        .memory_read_data(mem_read_data),
        .memory_address(mem_address), .memory_write_data(mem_write_data),
        .byte_write_enable(byte_we), .memory_read_enable(mem_read_en),
        .load_data(load_data), .access_valid(access_valid)
    );

    rv32i_data_memory u_dmem (
        .clk(clk), .reset(reset),
        .address(mem_address), .write_data(mem_write_data),
        .byte_write_enable(byte_we), .read_enable(mem_read_en),
        .read_data(mem_read_data)
    );
endmodule
