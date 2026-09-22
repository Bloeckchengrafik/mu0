`default_nettype none

module uart #(
    parameter DELAY_FRAMES = 234  // 27,000,000 (27Mhz) / 115200 Baud rate
) (
    input clk,
    input uart_rx,
    output uart_tx,
    output overrideMemControl,
    output overrideMemRnW,
    output [15:0] overrideMemAddr,
    output [15:0] overrideMemDataIn,
    input [15:0] overrideMemDataOut,
    output start,
    input enable,
    input [15:0] dbgIr,
    input [15:0] dbgPc,
    input [15:0] dbgAcc,
    input [8:0] dbgState,
    output [3:0] clkMode,
    input [15:0] dbgAluResult,
    input [3:0] dbgAluOp
);

    localparam HALF_DELAY_WAIT = (DELAY_FRAMES / 2);

    reg [3:0] rxState = 0;
    reg [12:0] rxCounter = 0;
    reg [7:0] dataIn = 0;
    reg [2:0] rxBitNumber = 0;
    reg byteReady = 0;

    localparam RX_STATE_IDLE = 0;
    localparam RX_STATE_START_BIT = 1;
    localparam RX_STATE_READ_WAIT = 2;
    localparam RX_STATE_READ = 3;
    localparam RX_STATE_STOP_BIT = 5;

    always @(posedge clk) begin
        case (rxState)
            RX_STATE_IDLE: begin
                if (uart_rx == 0) begin
                    rxState <= RX_STATE_START_BIT;
                    rxCounter <= 1;
                    rxBitNumber <= 0;
                end
                byteReady <= 0;
            end
            RX_STATE_START_BIT: begin
                if (rxCounter == HALF_DELAY_WAIT) begin
                    rxState   <= RX_STATE_READ_WAIT;
                    rxCounter <= 1;
                end else rxCounter <= rxCounter + 1;
            end
            RX_STATE_READ_WAIT: begin
                rxCounter <= rxCounter + 1;
                if ((rxCounter + 1) == DELAY_FRAMES) begin
                    rxState <= RX_STATE_READ;
                end
            end
            RX_STATE_READ: begin
                rxCounter <= 1;
                dataIn <= {uart_rx, dataIn[7:1]};
                rxBitNumber <= rxBitNumber + 1;
                if (rxBitNumber == 3'b111) rxState <= RX_STATE_STOP_BIT;
                else rxState <= RX_STATE_READ_WAIT;
            end
            RX_STATE_STOP_BIT: begin
                rxCounter <= rxCounter + 1;
                if ((rxCounter + 1) == DELAY_FRAMES) begin
                    rxState   <= RX_STATE_IDLE;
                    rxCounter <= 0;
                    byteReady <= 1;
                end
            end
        endcase
    end

    reg [3:0] txState = 0;
    reg [24:0] txCounter = 0;
    wire [7:0] dataOut;
    reg txPinRegister = 1;
    reg [2:0] txBitNumber = 0;
    wire byteReadyOut;
    reg byteSending = 0;

    assign uart_tx = txPinRegister;

    localparam TX_STATE_IDLE = 0;
    localparam TX_STATE_START_BIT = 1;
    localparam TX_STATE_WRITE = 2;
    localparam TX_STATE_STOP_BIT = 3;
    localparam TX_STATE_DEBOUNCE = 4;

    always @(posedge clk) begin
        case (txState)
            TX_STATE_IDLE: begin
                if (byteReadyOut) begin
                    txState <= TX_STATE_START_BIT;
                    txCounter <= 0;
                    byteSending <= 1;
                end else begin
                    txPinRegister <= 1;
                end
            end
            TX_STATE_START_BIT: begin
                txPinRegister <= 0;
                if ((txCounter + 1) == DELAY_FRAMES) begin
                    txState <= TX_STATE_WRITE;
                    txBitNumber <= 0;
                    txCounter <= 0;
                end else txCounter <= txCounter + 1;
            end
            TX_STATE_WRITE: begin
                txPinRegister <= dataOut[txBitNumber];
                if ((txCounter + 1) == DELAY_FRAMES) begin
                    if (txBitNumber == 3'b111) begin
                        txState <= TX_STATE_STOP_BIT;
                    end else begin
                        txState <= TX_STATE_WRITE;
                        txBitNumber <= txBitNumber + 1;
                    end
                    txCounter <= 0;
                end else txCounter <= txCounter + 1;
            end
            TX_STATE_STOP_BIT: begin
                txPinRegister <= 1;
                if ((txCounter + 1) == DELAY_FRAMES) begin
                    txState <= TX_STATE_DEBOUNCE;
                    txCounter <= 0;
                    byteSending <= 0;
                end else txCounter <= txCounter + 1;
            end
            TX_STATE_DEBOUNCE: begin
                if (txCounter == 23'b00001111111111111111111) begin
                    txState <= TX_STATE_IDLE;
                end else txCounter <= txCounter + 1;
            end
            default: begin
            end
        endcase
    end

    comm comm_inst (
        .clk(clk),
        .byteReady(byteReady),
        .dataIn(dataIn),
        .byteReadyOut(byteReadyOut),
        .dataOut(dataOut),
        .byteSending(byteSending),
        .overrideMemControl(overrideMemControl),
        .overrideMemRnW(overrideMemRnW),
        .overrideMemAddr(overrideMemAddr),
        .overrideMemDataIn(overrideMemDataIn),
        .overrideMemDataOut(overrideMemDataOut),
        .start(start),
        .enable(enable),
        .dbgIr(dbgIr),
        .dbgPc(dbgPc),
        .dbgAcc(dbgAcc),
        .dbgState(dbgState),
        .clkMode(clkMode),
        .dbgAluResult(dbgAluResult),
        .dbgAluOp(dbgAluOp)
    );
endmodule
