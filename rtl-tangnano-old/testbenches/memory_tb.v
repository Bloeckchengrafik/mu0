
`timescale 1ns / 1ps

module memory_tb;
    // Inputs
    reg memRq;
    reg readNotWrite;
    reg [15:0] addr;
    reg [15:0] dataIn;

    // Outputs
    wire [15:0] dataOut;

    // Instantiate the memory module
    memory uut (
        .memRq(memRq),
        .readNotWrite(readNotWrite),
        .addr(addr),
        .dataOut(dataOut),
        .dataIn(dataIn)
    );

    // VCD dump
    initial begin
        $dumpfile("memory.vcd");
        $dumpvars(0, memory_tb);
    end

    // Test sequence
    initial begin
        $display("Starting Memory test");

        // Initialize inputs
        memRq = 0;
        readNotWrite = 0;
        addr = 0;
        dataIn = 0;
        #10;

        // Test 1: Write to address 0
        memRq = 1;
        readNotWrite = 0;
        addr = 8'h00;
        dataIn = 8'hAA;
        #10;

        // Test 2: Read from address 0
        readNotWrite = 1;
        #10;
        if (dataOut !== 8'hAA) $display("Test 2 Failed: Expected 0xAA, got %h", dataOut);
        else $display("Test 2 Passed: Read correct value from addr 0");

        // Test 3: Write to address 31
        readNotWrite = 0;
        addr = 8'h1F;
        dataIn = 8'h55;
        #10;

        // Test 4: Read from address 31
        readNotWrite = 1;
        #10;
        if (dataOut !== 8'h55) $display("Test 4 Failed: Expected 0x55, got %h", dataOut);
        else $display("Test 4 Passed: Read correct value from addr 31");

        // Test 5: Test memRq disabled
        memRq = 0;
        #10;
        if (dataOut !== 8'hFF)
            $display("Test 5 Failed: Expected 0xFF when memRq=0, got %h", dataOut);
        else $display("Test 5 Passed: Correct default value when memRq=0");

        // End simulation
        #10;
        $display("Memory test complete");
        $finish;
    end

endmodule
