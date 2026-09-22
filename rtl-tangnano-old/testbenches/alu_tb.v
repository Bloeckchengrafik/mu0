`timescale 1ns / 1ps

module alu_tb;
    // Inputs
    reg  [15:0] a;
    reg  [15:0] b;
    reg  [ 3:0] op;

    // Outputs
    wire [15:0] result;

    // Instantiate the ALU
    alu uut (
        .a(a),
        .b(b),
        .op(op),
        .result(result)
    );

    // VCD dump
    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);
    end

    // Test helper task
    task check_result;
        input [15:0] expected;
        input [31:0] test_num;
        begin
            if (result !== expected) begin
                $display("Test %0d Failed: Expected %h, got %h", test_num, expected, result);
            end else begin
                $display("Test %0d Passed", test_num);
            end
        end
    endtask

    // Test sequence
    initial begin
        $display("Starting ALU test");

        // Initialize inputs
        a  = 0;
        b  = 0;
        op = 0;
        #10;

        // Test 1: OP_ZERO
        a  = 16'hFFFF;
        b  = 16'hFFFF;
        op = 0;  // OP_ZERO
        #10;
        check_result(16'h0000, 1);

        // Test 2: OP_ADD
        a  = 16'h1234;
        b  = 16'h5678;
        op = 1;  // OP_ADD
        #10;
        check_result(16'h68AC, 2);  // 1234 + 5678 = 68AC

        // Test 3: OP_SUB
        a  = 16'h5678;
        b  = 16'h1234;
        op = 2;  // OP_SUB
        #10;
        check_result(16'h4444, 3);  // 5678 - 1234 = 4444

        // Test 4: OP_A_INC
        a  = 16'hFFFF;
        b  = 16'h0000;
        op = 3;  // OP_A_INC
        #10;
        check_result(16'h0000, 4);  // FFFF + 1 = 0000 (overflow)

        // Test 5: OP_B
        a  = 16'hFFFF;
        b  = 16'h1234;
        op = 4;  // OP_B
        #10;
        check_result(16'h1234, 5);

        // Test 6: Invalid op
        op = 4'hF;  // Invalid op
        #10;
        check_result(16'h0000, 6);  // Should default to 0

        // Test 7: Addition with overflow
        a  = 16'hFFFF;
        b  = 16'h0001;
        op = 1;  // OP_ADD
        #10;
        check_result(16'h0000, 7);

        // Test 8: Subtraction with negative result
        a  = 16'h0000;
        b  = 16'h0001;
        op = 2;  // OP_SUB
        #10;
        check_result(16'hFFFF, 8);

        // End simulation
        #10;
        $display("ALU test complete");
        $finish;
    end

endmodule
