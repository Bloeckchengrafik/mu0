`timescale 1ns / 1ps

module mux_tb ();
    reg [15:0] dataIn0 = 16'h0000, dataIn1 = 16'h0001;
    reg clk = 0;
    reg select;
    wire [15:0] dataOut;
    mux dut (
        .dataIn0(dataIn0),
        .dataIn1(dataIn1),
        .select (select),
        .dataOut(dataOut)
    );


    initial begin
        $dumpfile("mux.vcd");
        $dumpvars(0, mux_tb);
    end

    always #1 clk = ~clk;
    initial begin
        $display("Starting Mux test");
        #10 select = 1'b0;
        #10 select = 1'b1;
        #10 select = 1'b0;
        #10 select = 1'b0;
        #10 select = 1'b0;
        #10 select = 1'b1;
        #10 select = 1'b1;
        #10 select = 1'b0;
        #10 select = 1'b1;
        #1000 $finish;
    end
endmodule
