`default_nettype none

module uart #(
    parameter logic [24:0] DELAY_FRAMES = 25'd234  // 27 MHz / 115200 baud
) (
    input  logic        clk,
    input  logic        uart_rx,
    output logic        uart_tx,
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
    localparam logic [12:0] RX_DELAY_FRAMES = DELAY_FRAMES[12:0];
    localparam logic [12:0] HALF_DELAY_WAIT = RX_DELAY_FRAMES / 2;
    localparam logic [24:0] TX_DELAY_FRAMES = DELAY_FRAMES;

    localparam logic [3:0] RX_STATE_IDLE      = 4'd0;
    localparam logic [3:0] RX_STATE_START_BIT = 4'd1;
    localparam logic [3:0] RX_STATE_READ_WAIT = 4'd2;
    localparam logic [3:0] RX_STATE_READ      = 4'd3;
    localparam logic [3:0] RX_STATE_STOP_BIT  = 4'd5;

    logic [3:0]  rxState = RX_STATE_IDLE;
    logic [12:0] rxCounter = 13'd0;
    logic [7:0]  dataIn = 8'd0;
    logic [2:0]  rxBitNumber = 3'd0;
    logic        byteReady = 1'b0;

    always_ff @(posedge clk) begin
        case (rxState)
            RX_STATE_IDLE: begin
                if (uart_rx == 1'b0) begin
                    rxState <= RX_STATE_START_BIT;
                    rxCounter <= 13'd1;
                    rxBitNumber <= 3'd0;
                end
                byteReady <= 1'b0;
            end

            RX_STATE_START_BIT: begin
                if (rxCounter == HALF_DELAY_WAIT) begin
                    rxState <= RX_STATE_READ_WAIT;
                    rxCounter <= 13'd1;
                end else begin
                    rxCounter <= rxCounter + 1'b1;
                end
            end

            RX_STATE_READ_WAIT: begin
                rxCounter <= rxCounter + 1'b1;
                if ((rxCounter + 13'd1) == RX_DELAY_FRAMES) begin
                    rxState <= RX_STATE_READ;
                end
            end

            RX_STATE_READ: begin
                rxCounter <= 13'd1;
                dataIn <= {uart_rx, dataIn[7:1]};
                rxBitNumber <= rxBitNumber + 1'b1;
                if (rxBitNumber == 3'b111) begin
                    rxState <= RX_STATE_STOP_BIT;
                end else begin
                    rxState <= RX_STATE_READ_WAIT;
                end
            end

            RX_STATE_STOP_BIT: begin
                rxCounter <= rxCounter + 1'b1;
                if ((rxCounter + 13'd1) == RX_DELAY_FRAMES) begin
                    rxState <= RX_STATE_IDLE;
                    rxCounter <= 13'd0;
                    byteReady <= 1'b1;
                end
            end

            default: begin
                rxState <= RX_STATE_IDLE;
                rxCounter <= 13'd0;
                byteReady <= 1'b0;
            end
        endcase
    end

    localparam logic [3:0] TX_STATE_IDLE      = 4'd0;
    localparam logic [3:0] TX_STATE_START_BIT = 4'd1;
    localparam logic [3:0] TX_STATE_WRITE     = 4'd2;
    localparam logic [3:0] TX_STATE_STOP_BIT  = 4'd3;
    localparam logic [3:0] TX_STATE_DEBOUNCE  = 4'd4;

    logic [3:0]  txState = TX_STATE_IDLE;
    logic [24:0] txCounter = 25'd0;
    logic [2:0]  txBitNumber = 3'd0;
    logic        txPinRegister = 1'b1;
    logic        byteSending = 1'b0;
    logic [7:0]  dataOut;
    logic        byteReadyOut;

    assign uart_tx = txPinRegister;

    always_ff @(posedge clk) begin
        case (txState)
            TX_STATE_IDLE: begin
                if (byteReadyOut) begin
                    txState <= TX_STATE_START_BIT;
                    txCounter <= 25'd0;
                    byteSending <= 1'b1;
                end else begin
                    txPinRegister <= 1'b1;
                end
            end

            TX_STATE_START_BIT: begin
                txPinRegister <= 1'b0;
                if ((txCounter + 25'd1) == TX_DELAY_FRAMES) begin
                    txState <= TX_STATE_WRITE;
                    txBitNumber <= 3'd0;
                    txCounter <= 25'd0;
                end else begin
                    txCounter <= txCounter + 1'b1;
                end
            end

            TX_STATE_WRITE: begin
                txPinRegister <= dataOut[txBitNumber];
                if ((txCounter + 25'd1) == TX_DELAY_FRAMES) begin
                    if (txBitNumber == 3'b111) begin
                        txState <= TX_STATE_STOP_BIT;
                    end else begin
                        txState <= TX_STATE_WRITE;
                        txBitNumber <= txBitNumber + 1'b1;
                    end
                    txCounter <= 25'd0;
                end else begin
                    txCounter <= txCounter + 1'b1;
                end
            end

            TX_STATE_STOP_BIT: begin
                txPinRegister <= 1'b1;
                if ((txCounter + 25'd1) == TX_DELAY_FRAMES) begin
                    txState <= TX_STATE_DEBOUNCE;
                    txCounter <= 25'd0;
                    byteSending <= 1'b0;
                end else begin
                    txCounter <= txCounter + 1'b1;
                end
            end

            TX_STATE_DEBOUNCE: begin
                if (txCounter == 25'd8191) begin
                    txState <= TX_STATE_IDLE;
                end else begin
                    txCounter <= txCounter + 1'b1;
                end
            end

            default: begin
                txState <= TX_STATE_IDLE;
                txCounter <= 25'd0;
                txPinRegister <= 1'b1;
                byteSending <= 1'b0;
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

`default_nettype wire
