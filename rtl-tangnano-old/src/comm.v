`default_nettype none


/**
 * @brief The comm module is used to control the uart communication and
 * internal execution state machine.
 * You can get a debug string: [16xir][16xpc][16xacc][8xstate][16xaluResult][8xaluOp]
 *   localparam CLK_OFF = 0;
 *   localparam CLK_FAST = 1;
 *   localparam CLK_SLOW = 2;
 *   localparam CLK_MANUAL_OFF = 3;
 *   localparam CLK_MANUAL_ON = 4;
 *
 * The protocol is defined as follows:
 * - p: Ping, just sends back a pong (P)
 * - r: Read memory, sends back the full memory values
 * - w: Write memory, writes the value specified in the next 64 bytes to the ram
 * - x: Execute code, start at 0
 * - s: Get the status of the execution state machine (+/-)
 * - To get debug data: iIcCaASlLo
 * - set clock: 0 1 2 3 4 etc
 */
module comm (
    input clk,
    input [7:0] dataIn,
    input byteSending,
    output reg byteReady,
    output reg byteReadyOut,
    output reg [7:0] dataOut,
    output reg overrideMemControl,
    output reg overrideMemRnW,
    output reg [15:0] overrideMemAddr,
    output reg [15:0] overrideMemDataIn,
    input [15:0] overrideMemDataOut,
    output reg start,
    input enable,
    input [15:0] dbgIr,
    input [15:0] dbgPc,
    input [15:0] dbgAcc,
    input [8:0] dbgState,
    output reg [3:0] clkMode = 0,
    input [15:0] dbgAluResult,
    input [3:0] dbgAluOp
);
    localparam COMM_STATE_IDLE = 0;
    localparam COMM_STATE_RXMEM = 2;
    localparam COMM_STATE_EXSTART = 3;
    localparam COMM_STATE_EXSTATE = 4;
    localparam COMM_STATE_TXMEM = 5;

    localparam MAX_MEMORY_COUNT = 32;

    localparam CLK_OFF = 0;
    localparam CLK_FAST = 1;
    localparam CLK_SLOW = 2;
    localparam CLK_MANUAL_OFF = 3;
    localparam CLK_MANUAL_ON = 4;

    initial begin
        byteReadyOut = 0;
        dataOut = 0;
        overrideMemControl = 0;
        overrideMemRnW = 0;
        overrideMemAddr = 0;
        overrideMemDataIn = 0;
    end

    reg [3:0] commState = COMM_STATE_IDLE;
    reg byteReceived = 0;
    reg [7:0] memCounter = 0;
    reg [7:0] lastRxByte = 0;
    reg [1:0] hasReceivedLastByte = 0;

    always @(posedge clk) begin
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
                            start = ~start;
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
                            memCounter <= 0;
                            byteReadyOut <= 1'b1;
                            dataOut <= "R";
                            hasReceivedLastByte <= 2'b0;
                        end
                        "w": begin
                            commState <= COMM_STATE_RXMEM;
                            memCounter <= 0;
                            byteReadyOut <= 1'b1;
                            hasReceivedLastByte <= 2'b0;
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
                            dataOut = dbgPc[7:0];
                        end
                        "a": begin
                            byteReadyOut <= 1'b1;
                            dataOut = dbgAcc[15:8];
                        end
                        "A": begin
                            byteReadyOut <= 1'b1;
                            dataOut = dbgAcc[7:0];
                        end
                        "S": begin
                            byteReadyOut <= 1'b1;
                            dataOut = dbgState;
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
                            dataOut = dbgAluResult[15:8];
                        end
                        "L": begin
                            byteReadyOut <= 1'b1;
                            dataOut = dbgAluResult[7:0];
                        end
                        "o": begin
                            byteReadyOut <= 1'b1;
                            dataOut = {4'b0000, dbgAluOp};
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
                        overrideMemAddr = memCounter;
                        overrideMemControl = 1'b1;
                        overrideMemRnW = 1'b1;
                        if (hasReceivedLastByte == 2'b0) begin
                            hasReceivedLastByte = 2'b01;
                            dataOut <= 8'b11111111;
                        end else if (hasReceivedLastByte == 2'b01) begin
                            dataOut <= overrideMemDataOut[7:0];
                            hasReceivedLastByte <= 2'b10;
                        end else begin
                            dataOut <= overrideMemDataOut[15:8];
                            memCounter <= memCounter + 1;
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
                        if (hasReceivedLastByte) begin
                            overrideMemControl <= 1'b1;
                            overrideMemAddr <= memCounter;
                            overrideMemRnW <= 1'b0;
                            dataOut <= "-";
                            overrideMemDataIn <= {dataIn, lastRxByte};
                            memCounter <= memCounter + 1;
                            hasReceivedLastByte <= 1'b0;
                            byteReadyOut <= 1'b1;
                        end else begin
                            byteReadyOut <= 1'b1;
                            dataOut <= "+";
                            lastRxByte <= dataIn;
                            hasReceivedLastByte <= 1'b1;
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
                    dataOut <= 8'b0;
                end
            endcase
        end

        if (byteSending) begin
            byteReadyOut <= 1'b0;
            byteReceived <= 1'b0;
        end
    end

endmodule
