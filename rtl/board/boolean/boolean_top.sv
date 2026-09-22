module boolean_top (
    input  logic clk,
    input  logic [15:0] sw,
    output logic [15:0] led,
);

    logic [25:0] counter;

    always_ff @(posedge clk) begin
        counter <= counter + 1;
    end

    assign led = counter[25] ^ sw;

endmodule
