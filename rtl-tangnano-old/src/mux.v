module mux (
    input [15:0] dataIn0,
    input [15:0] dataIn1,
    input select,
    output [15:0] dataOut
);
    assign dataOut = select ? dataIn1 : dataIn0;
endmodule
