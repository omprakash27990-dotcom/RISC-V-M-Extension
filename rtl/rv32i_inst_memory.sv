module rv32i_inst_memory #(
    parameter logic [31:0] BASE_ADDR = 32'h80000000,
    parameter integer MEM_BYTES = 262144
) (
    input  logic [31:0] address,
    output logic [31:0] instruction
);
    logic [7:0] mem [0:MEM_BYTES-1];
    logic [31:0] aligned_address;
    logic [31:0] offset;

    assign aligned_address = {address[31:2], 2'b00};
    assign offset = aligned_address - BASE_ADDR;

    always_comb begin
        instruction = 32'h00000013;
        if (aligned_address >= BASE_ADDR && (offset + 3) < MEM_BYTES)
            instruction = {mem[offset+3], mem[offset+2], mem[offset+1], mem[offset]};
    end
endmodule
