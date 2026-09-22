module alu (
    input [15:0] a,
    input [15:0] b,
    input [3:0] op,
    output reg [15:0] result
);
    localparam OP_ZERO = 0;
    localparam OP_ADD = 1;
    localparam OP_SUB = 2;
    localparam OP_A_INC = 3;
    localparam OP_B = 4;

    always @* begin
        case (op)
            OP_ZERO: result = 0;
            OP_ADD: result = a + b;
            OP_SUB: result = a - b;
            OP_A_INC: result = a + 1;
            OP_B: result = b;
            default: result = 0;
        endcase
    end
endmodule
