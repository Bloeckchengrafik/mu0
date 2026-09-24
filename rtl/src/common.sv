package common_pkg;
    typedef enum logic [3:0] {
        CLK_OFF        = 4'd0,
        CLK_FAST       = 4'd1,
        CLK_SLOW       = 4'd2,
        CLK_MANUAL_OFF = 4'd3,
        CLK_MANUAL_ON  = 4'd4
    } clk_mode_t;
endpackage
