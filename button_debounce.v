`timescale 1ns / 1ps

module button_debounce(
    input wire clk,
    input wire rst_n,
    input wire btn_in,
    output reg btn_out
);
    // 15ms @ 25MHz = 375,000 cycles (debounce time matched to actual clock)
    parameter CNT_MAX = 21'd300_000; 
    
    reg [20:0] cnt;
    reg btn_sync_0, btn_sync_1; 
    
    // Stage 1: Signal synchronization (correct as-is)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end
    
    // Stage 2: Debounce counting (critical fix)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 21'd0;
            btn_out <= 1'b1; // FIX: Reset to 1 (button has pull-up, normally HIGH)
        end else begin
            // If synchronized input signal equals current output signal
            if (btn_sync_1 == btn_out) begin
                cnt <= 21'd0; // Reset counter, wait for next change
            end else begin
                // State mismatch, start counting
                cnt <= cnt + 1'b1;
                if (cnt == CNT_MAX) begin
                    btn_out <= btn_sync_1; // Update output only after CNT_MAX cycles
                end
            end
        end
    end
endmodule
