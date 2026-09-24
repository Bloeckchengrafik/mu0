`default_nettype none
import common_pkg::*;

module boolean_top (
    input  logic       clk,
    input  logic       uart_rx,
    output logic       uart_tx,
    output logic [5:0] led
);

    logic        overrideMemControl;
    logic        overrideMemRnW;
    logic [15:0] overrideMemAddr;
    logic [15:0] overrideMemDataIn;
    logic [15:0] overrideMemDataOut;
    logic        enable = 1'b0;
    logic        slowClk = 1'b0;
    logic        done;
    logic        start;
    logic [15:0] ir;
    clk_mode_t  clkMode;

    logic [15:0] dbgPc;
    logic [15:0] dbgAcc;
    logic [7:0]  dbgState;
    logic [15:0] dbgAluResult;
    logic [3:0]  dbgAluOp;

    mu0 mu0_inst (
        .clk(slowClk & enable),
        .fastClk(clk),
        .overrideMemControl(overrideMemControl),
        .overrideMemRnW(overrideMemRnW),
        .overrideMemAddr(overrideMemAddr),
        .overrideMemDataIn(overrideMemDataIn),
        .overrideMemDataOut(overrideMemDataOut),
        .enable(enable),
        .done(done),
        .start(start),
        .ir(ir),
        .pc(dbgPc),
        .acc(dbgAcc),
        .state(dbgState),
        .dbgAluResult(dbgAluResult),
        .dbgAluOp(dbgAluOp)
    );

    assign led[0] = ~slowClk;
    assign led[1] = ~enable;
    assign led[2] = ~overrideMemControl;
    assign led[3] = ~ir[14];
    assign led[4] = ~ir[13];
    assign led[5] = ~ir[12];

    uart uart_inst (
        .clk(clk),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .overrideMemControl(overrideMemControl),
        .overrideMemRnW(overrideMemRnW),
        .overrideMemAddr(overrideMemAddr),
        .overrideMemDataIn(overrideMemDataIn),
        .overrideMemDataOut(overrideMemDataOut),
        .start(start),
        .enable(enable),
        .dbgIr(ir),
        .dbgPc(dbgPc),
        .dbgAcc(dbgAcc),
        .dbgState(dbgState),
        .clkMode(clkMode),
        .dbgAluResult(dbgAluResult),
        .dbgAluOp(dbgAluOp)
    );

    logic [31:0] clkCounter = 32'd0;
    logic        oldStart = 1'b0;

    always_ff @(posedge clk) begin
        if (done) begin
            enable <= 1'b0;
        end
        if (start != oldStart) begin
            oldStart <= start;
            enable   <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (clkMode == CLK_MANUAL_ON) begin
            slowClk <= 1'b1;
        end else if (clkMode == CLK_MANUAL_OFF) begin
            slowClk <= 1'b0;
        end else if (clkMode == CLK_SLOW) begin
            if (clkCounter >= 32'd6318000) begin
                clkCounter <= 32'd0;
                slowClk <= ~slowClk;
            end else begin
                clkCounter <= clkCounter + 1'b1;
            end
        end else if (clkMode == CLK_FAST) begin
            slowClk <= ~slowClk;
        end else begin
            slowClk <= 1'b0;
        end
    end
endmodule

`default_nettype wire
