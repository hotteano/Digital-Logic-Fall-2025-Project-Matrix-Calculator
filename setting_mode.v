// ========================================
// Matrix Setting Mode (RESTRUCTURED)
// Purpose: Configure system parameters
// ========================================

`timescale 1ns / 1ps
`include "matrix_pkg.vh"

module setting_mode #(
    parameter ELEMENT_WIDTH = `ELEMENT_WIDTH
)(
    input wire clk,
    input wire rst_n,
    input wire mode_active,
    
    // UART receive interface
    input wire [7:0] rx_data,
    input wire rx_done,
    output reg clear_rx_buffer,
    
    // UART transmit interface
    output reg [7:0] tx_data,
    output reg tx_start,
    input wire tx_busy,
    
    // Configuration output
    output reg [3:0] config_max_dim,
    output reg [3:0] config_max_value,
    output reg [3:0] config_matrices_per_size,
    
    // Error and state output
    output reg [3:0] error_code,
    output reg [3:0] sub_state
);

// State definitions
localparam IDLE = 4'd0, WAIT_MAX_DIM = 4'd1, WAIT_MAX_VAL = 4'd2,
           WAIT_MAT_PER_SIZE = 4'd3, CONFIRM = 4'd4, DONE = 4'd5;

// Internal configuration
reg [3:0] cfg_max_dim;
reg [3:0] cfg_max_value;
reg [3:0] cfg_matrices_per_size;
reg [7:0] parse_accum;        // Accumulator for multi-digit number

// Prompt display counter (for message cycling)
reg [1:0] message_state;
localparam MSG_DIM = 2'd0, MSG_VALUE = 2'd1, MSG_MATRICES = 2'd2, MSG_CONFIRM = 2'd3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sub_state <= IDLE;
        config_max_dim <= `DEFAULT_MAX_DIM;
        config_max_value <= `DEFAULT_MAX_VALUE;
        config_matrices_per_size <= `DEFAULT_MATRICES_PER_SIZE;
        cfg_max_dim <= `DEFAULT_MAX_DIM;
        cfg_max_value <= `DEFAULT_MAX_VALUE;
        cfg_matrices_per_size <= `DEFAULT_MATRICES_PER_SIZE;
        tx_start <= 1'b0;
        tx_data <= 8'd0;
        error_code <= `ERR_NONE;
        parse_accum <= 8'd0;
        message_state <= MSG_DIM;
        clear_rx_buffer <= 1'b0;
    end else if (mode_active) begin
        // Default one-shot signals
        tx_start <= 1'b0;
        clear_rx_buffer <= 1'b0;
        
        case (sub_state)
            IDLE: begin
                cfg_max_dim <= `DEFAULT_MAX_DIM;
                cfg_max_value <= `DEFAULT_MAX_VALUE;
                cfg_matrices_per_size <= `DEFAULT_MATRICES_PER_SIZE;
                parse_accum <= 8'd0;
                error_code <= `ERR_NONE;
                message_state <= MSG_DIM;
                sub_state <= WAIT_MAX_DIM;
            end
            
            WAIT_MAX_DIM: begin
                // Send prompt for max dimension
                if (!tx_busy && !tx_start) begin
                    case (message_state)
                        MSG_DIM: begin
                            tx_data <= "D";  // 'D' for Dimension
                            tx_start <= 1'b1;
                            message_state <= MSG_DIM + 1;
                        end
                        default: begin
                            // Prompt sent, wait for input
                            if (rx_done) begin
                                if (rx_data >= "0" && rx_data <= "9") begin
                                    // Parse digit: accumulate using multiply-by-10 = (x<<3)+(x<<1)
                                    parse_accum <= (parse_accum << 3) + (parse_accum << 1) + (rx_data - "0");
                                    clear_rx_buffer <= 1'b1;
                                    // Echo the digit back
                                    if (!tx_busy) begin
                                        tx_data <= rx_data;
                                        tx_start <= 1'b1;
                                    end
                                end else if (rx_data == 8'h0D || rx_data == 8'h0A) begin
                                    // Enter key - confirm the value
                                    if (parse_accum > 0 && parse_accum <= `MAX_POSSIBLE_DIM) begin
                                        cfg_max_dim <= parse_accum[3:0];
                                        parse_accum <= 8'd0;
                                        message_state <= MSG_VALUE;
                                        sub_state <= WAIT_MAX_VAL;
                                    end else begin
                                        // Invalid dimension
                                        error_code <= `ERR_DIM_RANGE;
                                        parse_accum <= 8'd0;
                                        message_state <= MSG_DIM;
                                    end
                                    clear_rx_buffer <= 1'b1;
                                end
                            end
                        end
                    endcase
                end
            end
            
            WAIT_MAX_VAL: begin
                // Send prompt for max value
                if (!tx_busy && !tx_start) begin
                    case (message_state)
                        MSG_VALUE: begin
                            tx_data <= "V";  // 'V' for Value
                            tx_start <= 1'b1;
                            message_state <= MSG_VALUE + 1;
                        end
                        default: begin
                            // Prompt sent, wait for input
                            if (rx_done) begin
                                if (rx_data >= "0" && rx_data <= "9") begin
                                    // Parse digit
                                    parse_accum <= (parse_accum << 3) + (parse_accum << 1) + (rx_data - "0");
                                    clear_rx_buffer <= 1'b1;
                                    // Echo the digit back
                                    if (!tx_busy) begin
                                        tx_data <= rx_data;
                                        tx_start <= 1'b1;
                                    end
                                end else if (rx_data == 8'h0D || rx_data == 8'h0A) begin
                                    // Enter key - confirm the value
                                    if (parse_accum > 0 && parse_accum <= 255) begin
                                        cfg_max_value <= parse_accum[3:0];
                                        parse_accum <= 8'd0;
                                        message_state <= MSG_MATRICES;
                                        sub_state <= WAIT_MAT_PER_SIZE;
                                    end else begin
                                        // Invalid value
                                        error_code <= `ERR_VALUE_RANGE;
                                        parse_accum <= 8'd0;
                                        message_state <= MSG_VALUE;
                                    end
                                    clear_rx_buffer <= 1'b1;
                                end
                            end
                        end
                    endcase
                end
            end
            
            WAIT_MAT_PER_SIZE: begin
                // Send prompt for matrices per size
                if (!tx_busy && !tx_start) begin
                    case (message_state)
                        MSG_MATRICES: begin
                            tx_data <= "M";  // 'M' for Matrices
                            tx_start <= 1'b1;
                            message_state <= MSG_MATRICES + 1;
                        end
                        default: begin
                            // Prompt sent, wait for input
                            if (rx_done) begin
                                if (rx_data >= "0" && rx_data <= "9") begin
                                    // Parse digit
                                    parse_accum <= (parse_accum << 3) + (parse_accum << 1) + (rx_data - "0");
                                    clear_rx_buffer <= 1'b1;
                                    // Echo the digit back
                                    if (!tx_busy) begin
                                        tx_data <= rx_data;
                                        tx_start <= 1'b1;
                                    end
                                end else if (rx_data == 8'h0D || rx_data == 8'h0A) begin
                                    // Enter key - confirm the value
                                    if (parse_accum > 0 && parse_accum <= 20) begin
                                        cfg_matrices_per_size <= parse_accum[3:0];
                                        parse_accum <= 8'd0;
                                        message_state <= MSG_CONFIRM;
                                        sub_state <= CONFIRM;
                                    end else begin
                                        // Invalid matrices per size
                                        error_code <= `ERR_NO_SPACE;
                                        parse_accum <= 8'd0;
                                        message_state <= MSG_MATRICES;
                                    end
                                    clear_rx_buffer <= 1'b1;
                                end
                            end
                        end
                    endcase
                end
            end
            
            CONFIRM: begin
                // Send confirmation message 'S' for Settings Configured
                if (!tx_busy && !tx_start) begin
                    tx_data <= "S";
                    tx_start <= 1'b1;
                    // Apply the configuration
                    config_max_dim <= cfg_max_dim;
                    config_max_value <= cfg_max_value;
                    config_matrices_per_size <= cfg_matrices_per_size;
                    error_code <= `ERR_NONE;
                    sub_state <= DONE;
                end
            end
            
            DONE: begin
                sub_state <= IDLE;
            end
            
            default: sub_state <= IDLE;
        endcase
    end else begin
        sub_state <= IDLE;
        parse_accum <= 8'd0;
        message_state <= MSG_DIM;
    end
end

endmodule
