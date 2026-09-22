module memory (
    input             clk,
    input             memRq,
    input             readNotWrite,
    input      [15:0] addr,
    input      [15:0] dataIn,
    output reg [15:0] dataOut
);
    reg [15:0] memory[32];
    wire [4:0] mem_addr = addr[4:0];

    // Initialize memory (optional, useful for simulation)
    reg [4:0] i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            memory[i] = 16'b0101010101010101;
        end
    end

    always @(posedge clk) begin
        if (memRq && !readNotWrite) begin
            memory[mem_addr] <= dataIn;
        end
    end

    always @(*) begin
        if (memRq && readNotWrite) begin
            dataOut = memory[mem_addr];
        end else begin
            dataOut = 16'hbfbf;
        end
    end
endmodule
