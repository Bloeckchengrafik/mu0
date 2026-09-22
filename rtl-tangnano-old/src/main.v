module main (
    input clk,
    input uart_rx,
    output uart_tx,
    output reg [5:0] led,
    input btn1
);
    localparam CLK_OFF = 0;
    localparam CLK_FAST = 1;
    localparam CLK_SLOW = 2;
    localparam CLK_MANUAL_OFF = 3;
    localparam CLK_MANUAL_ON = 4;

    wire overrideMemControl;
    wire overrideMemRnW;
    wire [15:0] overrideMemAddr;
    wire [15:0] overrideMemDataIn;
    wire [15:0] overrideMemDataOut;
    reg enable = 0;
    reg slowClk;
    wire done;
    wire start;
    wire [15:0] ir;
    wire [3:0] clkMode;

    wire [15:0] dbgPc;
    wire [15:0] dbgAcc;
    wire [8:0] dbgState;

    wire [15:0] dbgAluResult;
    wire [3:0] dbgAluOp;

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

    assign led[0] = ~(slowClk);
    assign led[1] = ~enable;
    assign led[2] = ~overrideMemControl;
    assign led[3] = ~ir[14];
    assign led[4] = ~ir[13];
    assign led[5] = ~ir[12];

    uart uart (
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

    reg [31:0] clkCounter = 0;
    reg oldStart = 0;
    always @(posedge clk) begin
        if (done) begin
            enable = 0;
        end
        if (start != oldStart) begin
            oldStart = start;
            enable   = 1;
        end
    end

    always @(posedge clk) begin
        if (clkMode == CLK_MANUAL_ON) begin
            slowClk = 1;
        end else if (clkMode == CLK_MANUAL_OFF) begin
            slowClk = 0;
        end else if (clkMode == CLK_SLOW) begin
            clkCounter = clkCounter + 1;
            if (clkCounter > 6318000) begin
                clkCounter = 0;
                slowClk = ~slowClk;
            end
        end else if (clkMode == CLK_FAST) begin
            slowClk = ~slowClk;
        end else begin
            slowClk = 0;
        end
    end
endmodule
