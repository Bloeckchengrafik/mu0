module mu0 (
    input clk,
    input fastClk,
    input overrideMemControl,
    input overrideMemRnW,
    input [15:0] overrideMemAddr,
    input [15:0] overrideMemDataIn,
    input enable,
    output reg [15:0] overrideMemDataOut,
    output reg done = 0,
    input start,
    output reg [15:0] ir = 0,
    output reg [15:0] pc = 16'b0,
    output reg [15:0] acc = 0,
    output reg [7:0] state = 0,
    output [15:0] dbgAluResult,
    output [3:0] dbgAluOp
);
    localparam ALUOP_ZERO = 0;
    localparam ALUOP_ADD = 1;
    localparam ALUOP_SUB = 2;
    localparam ALUOP_A_INC = 3;
    localparam ALUOP_B = 4;

    reg memRq = 0;
    reg readNotWrite = 1;
    wire [15:0] dataIn;

    wire _memRq;
    wire _readNotWrite;
    wire [15:0] _addr;
    wire [15:0] _dataIn;
    wire [15:0] dataOut;

    memory mem (
        .clk(fastClk),
        .memRq(_memRq),
        .readNotWrite(_readNotWrite),
        .addr(_addr),
        .dataIn(_dataIn),
        .dataOut(dataOut),
    );

    reg aSel = 0;
    reg bSel = 0;

    reg accOe = 0;
    reg accIe = 0;

    reg pcOe = 0;
    reg pcIe = 0;

    reg irIe = 0;

    wire [15:0] busDataOut = accOe ? acc : (pcOe ? pc : 0);

    assign overrideMemDataOut = dataOut;
    assign _memRq = overrideMemControl ? 1 : memRq;
    assign _readNotWrite = overrideMemControl ? overrideMemRnW : readNotWrite;
    assign _addr = overrideMemControl ? overrideMemAddr : (aSel ? {4'b0, ir[11:0]} : busDataOut);
    assign _dataIn = overrideMemControl ? overrideMemDataIn : dataIn;

    assign dataIn = busDataOut;

    reg  [ 3:0] op = 0;
    wire [15:0] aluA = busDataOut;
    wire [15:0] aluB = bSel ? dataOut : {4'b0, ir[11:0]};
    wire [15:0] aluResult;

    alu comp (
        .op(op),
        .a(aluA),
        .b(aluB),
        .result(aluResult)
    );

    assign dbgAluResult = aluResult;
    assign dbgAluOp = op;

    localparam PROC_STATE_FETCH = 0;
    localparam PROC_STATE_FETCHSTORE = 1;
    localparam PROC_STATE_EXEC = 2;
    localparam PROC_STATE_STORE = 3;

    localparam OP_LDA = 4'b0000;
    localparam OP_STO = 4'b0001;
    localparam OP_ADD = 4'b0010;
    localparam OP_SUB = 4'b0011;
    localparam OP_JMP = 4'b0100;
    localparam OP_JGE = 4'b0101;
    localparam OP_JNE = 4'b0110;
    localparam OP_STP = 4'b0111;

    reg oldStart = 0;
    always @(posedge clk) begin
        if (oldStart != start) begin
            oldStart = start;
            state = PROC_STATE_FETCH;
            acc = 16'b0;
            pc = 16'b0;
            done = 0;
        end

        case (state)
            PROC_STATE_FETCH: begin
                aSel  = 0;
                accOe = 0;
                accIe = 0;
                pcOe  = 1;
                pcIe  = 1;
                irIe  = 1;
                op    = ALUOP_A_INC;
                memRq = 1;
                readNotWrite = 1;

                state = PROC_STATE_FETCHSTORE;
            end
            PROC_STATE_EXEC: begin
                state = PROC_STATE_STORE;
                case (ir[15:12])
                    OP_LDA: begin
                        aSel  = 1;
                        bSel  = 1;
                        accOe = 0;
                        accIe = 1;
                        pcOe  = 0;
                        pcIe  = 0;
                        irIe  = 0;
                        op    = ALUOP_B;
                        memRq = 1;
                        readNotWrite = 1;
                    end
                    OP_STO: begin
                        aSel = 1;
                        accOe = 1;
                        accIe = 0;
                        pcOe = 0;
                        pcIe = 0;
                        irIe = 0;
                        memRq = 1;
                        readNotWrite = 0;
                    end
                    OP_ADD: begin
                        aSel = 1;
                        bSel = 1;
                        accOe = 1;
                        accIe = 1;
                        pcOe = 0;
                        pcIe = 0;
                        irIe = 0;
                        op = ALUOP_ADD;
                        memRq = 1;
                        readNotWrite = 1;
                    end
                    OP_SUB: begin
                        aSel = 1;
                        bSel = 1;
                        accOe = 1;
                        accIe = 1;
                        pcOe = 0;
                        pcIe = 0;
                        irIe = 0;
                        op = ALUOP_SUB;
                        memRq = 1;
                        readNotWrite = 1;
                    end
                    OP_JMP: begin
                        bSel = 0;
                        accOe = 0;
                        accIe = 0;
                        pcOe = 0;
                        pcIe = 1;
                        irIe = 0;
                        op = ALUOP_B;
                        memRq = 0;
                        readNotWrite = 1;
                    end
                    OP_JGE: begin
                        bSel = 0;
                        accOe = 0;
                        accIe = 0;
                        pcOe = 0;
                        pcIe = ~acc[15];
                        irIe = 0;
                        op = ALUOP_B;
                        memRq = 0;
                        readNotWrite = 1;
                    end
                    OP_JNE: begin
                        bSel = 0;
                        accOe = 0;
                        accIe = 0;
                        pcOe = 0;
                        pcIe = acc != 0;
                        irIe = 0;
                        op = ALUOP_B;
                        memRq = 0;
                        readNotWrite = 1;
                    end
                    OP_STP: begin
                        done = 1'b1;
                    end
                endcase
            end
            PROC_STATE_FETCHSTORE, PROC_STATE_STORE: begin
                if (accIe) begin
                    acc = aluResult;
                end

                if (pcIe) begin
                    pc = aluResult;
                end

                if (irIe) begin
                    ir = dataOut;
                end

                if (state == PROC_STATE_FETCHSTORE) begin
                    state = PROC_STATE_EXEC;
                end else begin
                    state = PROC_STATE_FETCH;
                end
            end
        endcase
    end
endmodule
