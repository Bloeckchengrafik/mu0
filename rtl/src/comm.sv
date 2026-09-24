`default_nettype none

/**
 * @brief Controls UART communication and the internal execution state machine.
 * Debug byte commands: i/I (IR), c/C (PC), a/A (ACC), S (state),
 * l/L (ALU result), and o (ALU operation).
 */
module comm (
    input  logic        clk,
    input  logic        byteReady,
    input  logic [7:0]  dataIn,
    input  logic        byteSending,
    output logic        byteReadyOut,
    output logic [7:0]  dataOut,
    output logic        overrideMemControl,
    output logic        overrideMemRnW,
    output logic [15:0] overrideMemAddr,
    output logic [15:0] overrideMemDataIn,
    input  logic [15:0] overrideMemDataOut,
    output logic        start,
    input  logic        enable,
    input  logic [15:0] dbgIr,
    input  logic [15:0] dbgPc,
    input  logic [15:0] dbgAcc,
    input  logic [7:0]  dbgState,
    output common_pkg::clk_mode_t clkMode,
    input  logic [15:0] dbgAluResult,
    input  logic [3:0]  dbgAluOp
);
    typedef enum logic [3:0] {
        COMM_STATE_IDLE    = 4'd0,
        COMM_STATE_RXMEM   = 4'd2,
        COMM_STATE_EXSTART = 4'd3,
        COMM_STATE_EXSTATE = 4'd4,
        COMM_STATE_TXMEM   = 4'd5
    } comm_state_t;

    localparam logic [7:0] MAX_MEMORY_COUNT = 8'd32;

    localparam logic [3:0] CLK_OFF        = 4'd0;
    localparam logic [3:0] CLK_FAST       = 4'd1;
    localparam logic [3:0] CLK_SLOW       = 4'd2;
    localparam logic [3:0] CLK_MANUAL_OFF = 4'd3;
    localparam logic [3:0] CLK_MANUAL_ON  = 4'd4;

    comm_state_t commState = COMM_STATE_IDLE;
    logic byteReceived = 1'b0;
    logic [7:0] memCounter = 8'd0;
    logic [7:0] lastRxByte = 8'd0;
    logic [1:0] hasReceivedLastByte = 2'b0;

    initial begin
        byteReadyOut = 1'b0;
        dataOut = 8'd0;
        overrideMemControl = 1'b0;
        overrideMemRnW = 1'b0;
        overrideMemAddr = 16'd0;
        overrideMemDataIn = 16'd0;
        start = 1'b0;
        clkMode = CLK_OFF;
    end

    always_ff @(posedge clk) begin
        if (byteReady && !byteSending && !byteReceived) begin
            byteReceived <= 1'b1;

            case (commState)
                COMM_STATE_IDLE: begin
                    case (dataIn)
                        "p": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "P";
                        end
                        "x": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "X";
                            start <= ~start;
                        end
                        "s": begin
                            byteReadyOut <= 1'b1;
                            if (enable) begin
                                dataOut <= "+";
                            end else begin
                                dataOut <= "-";
                            end
                        end
                        "r": begin
                            commState <= COMM_STATE_TXMEM;
                            memCounter <= 8'd0;
                            byteReadyOut <= 1'b1;
                            dataOut <= "R";
                            hasReceivedLastByte <= 2'b0;
                        end
                        "w": begin
                            commState <= COMM_STATE_RXMEM;
                            memCounter <= 8'd0;
                            byteReadyOut <= 1'b1;
                            dataOut <= "W";
                            hasReceivedLastByte <= 2'b0;
                        end
                        "i": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgIr[15:8];
                        end
                        "I": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgIr[7:0];
                        end
                        "c": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgPc[15:8];
                        end
                        "C": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgPc[7:0];
                        end
                        "a": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgAcc[15:8];
                        end
                        "A": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgAcc[7:0];
                        end
                        "S": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgState[7:0];
                        end
                        "0": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "Y";
                            clkMode <= CLK_OFF;
                        end
                        "1": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "Y";
                            clkMode <= CLK_FAST;
                        end
                        "2": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "Y";
                            clkMode <= CLK_SLOW;
                        end
                        "3": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "Y";
                            clkMode <= CLK_MANUAL_OFF;
                        end
                        "4": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "Y";
                            clkMode <= CLK_MANUAL_ON;
                        end
                        "l": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgAluResult[15:8];
                        end
                        "L": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= dbgAluResult[7:0];
                        end
                        "o": begin
                            byteReadyOut <= 1'b1;
                            dataOut <= {4'b0000, dbgAluOp};
                        end
                        default: begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "?";
                        end
                    endcase
                end

                COMM_STATE_TXMEM: begin
                    if (memCounter < MAX_MEMORY_COUNT) begin
                        byteReadyOut <= 1'b1;
                        overrideMemAddr <= {8'd0, memCounter};
                        overrideMemControl <= 1'b1;
                        overrideMemRnW <= 1'b1;
                        if (hasReceivedLastByte == 2'b0) begin
                            hasReceivedLastByte <= 2'b01;
                            dataOut <= 8'b11111111;
                        end else if (hasReceivedLastByte == 2'b01) begin
                            dataOut <= overrideMemDataOut[7:0];
                            hasReceivedLastByte <= 2'b10;
                        end else begin
                            dataOut <= overrideMemDataOut[15:8];
                            memCounter <= memCounter + 1'b1;
                            hasReceivedLastByte <= 2'b0;
                        end
                    end else begin
                        commState <= COMM_STATE_IDLE;
                        byteReadyOut <= 1'b1;
                        overrideMemControl <= 1'b0;
                        dataOut <= "E";
                    end
                end

                COMM_STATE_RXMEM: begin
                    if (memCounter < MAX_MEMORY_COUNT) begin
                        if (hasReceivedLastByte != 2'b0) begin
                            overrideMemControl <= 1'b1;
                            overrideMemAddr <= {8'd0, memCounter};
                            overrideMemRnW <= 1'b0;
                            dataOut <= "-";
                            overrideMemDataIn <= {dataIn, lastRxByte};
                            memCounter <= memCounter + 1'b1;
                            hasReceivedLastByte <= 2'b0;
                            byteReadyOut <= 1'b1;
                        end else begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "+";
                            lastRxByte <= dataIn;
                            hasReceivedLastByte <= 2'b1;
                        end
                    end else begin
                        commState <= COMM_STATE_IDLE;
                        byteReadyOut <= 1'b1;
                        overrideMemControl <= 1'b0;
                        dataOut <= "E";
                    end
                end

                default: begin
                    commState <= COMM_STATE_IDLE;
                    byteReadyOut <= 1'b0;
                    dataOut <= 8'd0;
                end
            endcase
        end

        if (byteSending) begin
            byteReadyOut <= 1'b0;
            byteReceived <= 1'b0;
        end
    end
endmodule

`default_nettype wire
