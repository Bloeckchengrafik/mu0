`default_nettype none

module memory (
    input  logic        clk,
    input  logic        memRq,
    input  logic        readNotWrite,
    input  logic [15:0] addr,
    input  logic [15:0] dataIn,
    output logic [15:0] dataOut
);
    logic [15:0] ram [0:31];
    logic [4:0] mem_addr;
    integer i;

    assign mem_addr = addr[4:0];

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            ram[i] = 16'b0101010101010101;
        end
    end

    always_ff @(posedge clk) begin
        if (memRq && !readNotWrite) begin
            ram[mem_addr] <= dataIn;
        end
    end

    always_comb begin
        if (memRq && readNotWrite) begin
            dataOut = ram[mem_addr];
        end else begin
            dataOut = 16'hbfbf;
        end
    end
endmodule

`default_nettype wire
