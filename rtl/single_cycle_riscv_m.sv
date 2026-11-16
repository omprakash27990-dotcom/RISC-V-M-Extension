
module single_cycle_riscv_m (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic [31:0] instruction,
    input  logic [31:0] mem_out,

    output logic [31:0] rs2_data,
    output logic [31:0] alu_out,
    output logic        mem_write,
    output logic        mem_read,
    output logic [2:0]  fn3,
    output logic [6:0]  opcode,
    output logic [31:0] address
);

    logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;

    logic [31:0] rs1_data;
    logic [31:0] immediate;
    logic [31:0] wb_data;

    logic branch_taken;
    logic redirect;
    logic [31:0] redirect_target;

    logic rf_we;
    logic [4:0] rf_waddr;
    logic [1:0] memtoreg;

    // Generate memory and register-file controls
    always_comb begin
        mem_read  = (opcode == 7'h03);
        mem_write = (opcode == 7'h23);

        rf_we    = 1'b0;
        memtoreg = 2'b00;

        case (opcode)
            7'h33, 7'h13:
                rf_we = 1'b1;

            7'h03: begin
                rf_we    = 1'b1;
                memtoreg = 2'b01;
            end

            7'h6f, 7'h67, 7'h37, 7'h17: begin
                rf_we    = 1'b1;
                memtoreg = 2'b10;
            end

            default: ;
        endcase
    end

    assign rf_waddr = rd;

    // Expose processor outputs
    assign address = pc_internal;
    assign alu_out = alu_result_internal;
    assign fn3     = funct3_internal;

    logic [31:0] pc_internal;
    logic [31:0] alu_result_internal;
    logic [2:0]  funct3_internal;

    // Existing processor core
    rv32i_if_id_ex u_core (
        .clk(clk),
        .reset(reset),

        .instruction_in(instruction),

        .rf_external_we(rf_we),
        .rf_external_waddr(rf_waddr),

        .mem_out(mem_out),
        .memtoreg(memtoreg),

        .pc(pc_internal),
        .instruction(),

        .opcode(opcode),
        .funct3(funct3_internal),
        .funct7(funct7),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .immediate(immediate),
        .alu_result(alu_result_internal),

        .wb_data(wb_data),

        .branch_taken(branch_taken),
        .redirect(redirect),
        .redirect_target(redirect_target)
    );

endmodule
