`default_nettype none

module mu0 (
    input  logic        clk,
    input  logic        fastClk,
    input  logic        overrideMemControl,
    input  logic        overrideMemRnW,
    input  logic [15:0] overrideMemAddr,
    input  logic [15:0] overrideMemDataIn,
    input  logic        enable,
    output logic [15:0] overrideMemDataOut,
    output logic        done = 1'b0,
    input  logic        start,
    output logic [15:0] ir = 16'd0,
    output logic [15:0] pc = 16'd0,
    output logic [15:0] acc = 16'd0,
    output logic [7:0]  state = 8'd0,
    output logic [15:0] dbgAluResult,
    output logic [3:0]  dbgAluOp
);
    localparam logic [3:0] ALUOP_ZERO = 4'd0;
    localparam logic [3:0] ALUOP_ADD  = 4'd1;
    localparam logic [3:0] ALUOP_SUB  = 4'd2;
    localparam logic [3:0] ALUOP_A_INC = 4'd3;
    localparam logic [3:0] ALUOP_B    = 4'd4;

    logic memRq = 1'b0;
    logic readNotWrite = 1'b1;
    logic [15:0] dataIn;
    logic _memRq;
    logic _readNotWrite;
    logic [15:0] _addr;
    logic [15:0] _dataIn;
    logic [15:0] dataOut;

    memory mem (
        .clk(fastClk),
        .memRq(_memRq),
        .readNotWrite(_readNotWrite),
        .addr(_addr),
        .dataIn(_dataIn),
        .dataOut(dataOut)
    );

    logic aSel = 1'b0;
    logic bSel = 1'b0;
    logic accOe = 1'b0;
    logic accIe = 1'b0;
    logic pcOe = 1'b0;
    logic pcIe = 1'b0;
    logic irIe = 1'b0;

    logic [15:0] busDataOut;
    logic [3:0] op = ALUOP_ZERO;
    logic [15:0] aluA;
    logic [15:0] aluB;
    logic [15:0] aluResult;

    assign busDataOut = accOe ? acc : (pcOe ? pc : 16'd0);
    assign overrideMemDataOut = dataOut;
    assign _memRq = overrideMemControl ? 1'b1 : memRq;
    assign _readNotWrite = overrideMemControl ? overrideMemRnW : readNotWrite;
    assign _addr = overrideMemControl ? overrideMemAddr : (aSel ? {4'b0, ir[11:0]} : busDataOut);
    assign _dataIn = overrideMemControl ? overrideMemDataIn : dataIn;
    assign dataIn = busDataOut;

    assign aluA = busDataOut;
    assign aluB = bSel ? dataOut : {4'b0, ir[11:0]};

    alu comp (
        .op(op),
        .a(aluA),
        .b(aluB),
        .result(aluResult)
    );

    assign dbgAluResult = aluResult;
    assign dbgAluOp = op;

    localparam logic [7:0] PROC_STATE_FETCH      = 8'd0;
    localparam logic [7:0] PROC_STATE_FETCHSTORE = 8'd1;
    localparam logic [7:0] PROC_STATE_EXEC       = 8'd2;
    localparam logic [7:0] PROC_STATE_STORE      = 8'd3;

    localparam logic [3:0] OP_LDA = 4'b0000;
    localparam logic [3:0] OP_STO = 4'b0001;
    localparam logic [3:0] OP_ADD = 4'b0010;
    localparam logic [3:0] OP_SUB = 4'b0011;
    localparam logic [3:0] OP_JMP = 4'b0100;
    localparam logic [3:0] OP_JGE = 4'b0101;
    localparam logic [3:0] OP_JNE = 4'b0110;
    localparam logic [3:0] OP_STP = 4'b0111;

    logic oldStart = 1'b0;

    always_ff @(posedge clk) begin
        if (oldStart != start) begin
            oldStart <= start;
            state <= PROC_STATE_FETCHSTORE;
            acc <= 16'd0;
            pc <= 16'd0;
            done <= 1'b0;

            aSel <= 1'b0;
            accOe <= 1'b0;
            accIe <= 1'b0;
            pcOe <= 1'b1;
            pcIe <= 1'b1;
            irIe <= 1'b1;
            op <= ALUOP_A_INC;
            memRq <= 1'b1;
            readNotWrite <= 1'b1;
        end else begin
            case (state)
                PROC_STATE_FETCH: begin
                    aSel <= 1'b0;
                    accOe <= 1'b0;
                    accIe <= 1'b0;
                    pcOe <= 1'b1;
                    pcIe <= 1'b1;
                    irIe <= 1'b1;
                    op <= ALUOP_A_INC;
                    memRq <= 1'b1;
                    readNotWrite <= 1'b1;
                    state <= PROC_STATE_FETCHSTORE;
                end

                PROC_STATE_EXEC: begin
                    state <= PROC_STATE_STORE;
                    case (ir[15:12])
                        OP_LDA: begin
                            aSel <= 1'b1;
                            bSel <= 1'b1;
                            accOe <= 1'b0;
                            accIe <= 1'b1;
                            pcOe <= 1'b0;
                            pcIe <= 1'b0;
                            irIe <= 1'b0;
                            op <= ALUOP_B;
                            memRq <= 1'b1;
                            readNotWrite <= 1'b1;
                        end
                        OP_STO: begin
                            aSel <= 1'b1;
                            accOe <= 1'b1;
                            accIe <= 1'b0;
                            pcOe <= 1'b0;
                            pcIe <= 1'b0;
                            irIe <= 1'b0;
                            memRq <= 1'b1;
                            readNotWrite <= 1'b0;
                        end
                        OP_ADD: begin
                            aSel <= 1'b1;
                            bSel <= 1'b1;
                            accOe <= 1'b1;
                            accIe <= 1'b1;
                            pcOe <= 1'b0;
                            pcIe <= 1'b0;
                            irIe <= 1'b0;
                            op <= ALUOP_ADD;
                            memRq <= 1'b1;
                            readNotWrite <= 1'b1;
                        end
                        OP_SUB: begin
                            aSel <= 1'b1;
                            bSel <= 1'b1;
                            accOe <= 1'b1;
                            accIe <= 1'b1;
                            pcOe <= 1'b0;
                            pcIe <= 1'b0;
                            irIe <= 1'b0;
                            op <= ALUOP_SUB;
                            memRq <= 1'b1;
                            readNotWrite <= 1'b1;
                        end
                        OP_JMP: begin
                            bSel <= 1'b0;
                            accOe <= 1'b0;
                            accIe <= 1'b0;
                            pcOe <= 1'b0;
                            pcIe <= 1'b1;
                            irIe <= 1'b0;
                            op <= ALUOP_B;
                            memRq <= 1'b0;
                            readNotWrite <= 1'b1;
                        end
                        OP_JGE: begin
                            bSel <= 1'b0;
                            accOe <= 1'b0;
                            accIe <= 1'b0;
                            pcOe <= 1'b0;
                            pcIe <= ~acc[15];
                            irIe <= 1'b0;
                            op <= ALUOP_B;
                            memRq <= 1'b0;
                            readNotWrite <= 1'b1;
                        end
                        OP_JNE: begin
                            bSel <= 1'b0;
                            accOe <= 1'b0;
                            accIe <= 1'b0;
                            pcOe <= 1'b0;
                            pcIe <= (acc != 16'd0);
                            irIe <= 1'b0;
                            op <= ALUOP_B;
                            memRq <= 1'b0;
                            readNotWrite <= 1'b1;
                        end
                        OP_STP: begin
                            done <= 1'b1;
                        end
                        default: begin
                        end
                    endcase
                end

                PROC_STATE_FETCHSTORE, PROC_STATE_STORE: begin
                    if (accIe) begin
                        acc <= aluResult;
                    end

                    if (pcIe) begin
                        pc <= aluResult;
                    end

                    if (irIe) begin
                        ir <= dataOut;
                    end

                    if (state == PROC_STATE_FETCHSTORE) begin
                        state <= PROC_STATE_EXEC;
                    end else begin
                        state <= PROC_STATE_FETCH;
                    end
                end

                default: begin
                end
            endcase
        end
    end
endmodule

`default_nettype wire
