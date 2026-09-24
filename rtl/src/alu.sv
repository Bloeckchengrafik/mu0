`default_nettype none

module alu (
    input  logic [3:0]  op,
    input  logic [15:0] a,
    input  logic [15:0] b,
    output logic [15:0] result
);
    typedef enum logic [3:0] {
        ALU_OP_ZERO = 4'd0,
        ALU_OP_ADD  = 4'd1,
        ALU_OP_SUB  = 4'd2,
        ALU_OP_A_INC = 4'd3,
        ALU_OP_B    = 4'd4
    } alu_operation_t;

    always_comb begin
        case (op)
            ALU_OP_ZERO:  result = 16'd0;
            ALU_OP_ADD:   result = a + b;
            ALU_OP_SUB:   result = a - b;
            ALU_OP_A_INC: result = a + 16'd1;
            ALU_OP_B:     result = b;
            default:      result = 16'd0;
        endcase
    end
endmodule

`default_nettype wire
