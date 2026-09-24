`default_nettype none

module mux (
    input  logic [15:0] dataIn0,
    input  logic [15:0] dataIn1,
    input  logic        select,
    output logic [15:0] dataOut
);
    assign dataOut = select ? dataIn1 : dataIn0;
endmodule

`default_nettype wire
