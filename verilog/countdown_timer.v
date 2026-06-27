// =========================================================================
// Project:     FPGA Smart Traffic Light Controller
// File:        countdown_timer.v
// Description: Dynamic countdown timer module that counts seconds based on
//              FPGA 50 MHz clock cycles. Used to regulate traffic phase durations.
// Board:       Intel/Altera DE2-115 (Cyclone IV E EP4CE115F29C7)
// Author:      Saksham Arora (24BEC0185)
// Course:      Digital System Design Lab (BECE102P)
// Instructor:  Dr. Vishal Gupta
// =========================================================================

module countdown_timer #(
    parameter integer CYCLES_PER_SEC = 50000000 // Configured to match input clock frequency
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        start,     // Trigger to load new value and begin countdown
    input  wire [3:0]  load_val,  // Duration value to load (0-9 range)
    output reg  [3:0]  time_left, // Current remaining duration count
    output reg         done       // High for one cycle when timer expires
);

    reg [31:0] cycle_count;
    reg        active;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_count <= 0;
            time_left   <= 0;
            active      <= 0;
            done        <= 0;
        end else if (start) begin
            cycle_count <= 0;
            // Cap the input load value to maximum single-digit decimal representation (9)
            time_left   <= (load_val > 9) ? 4'd9 : load_val;
            active      <= 1;
            done        <= 0;
        end else if (active) begin
            if (cycle_count >= CYCLES_PER_SEC - 1) begin
                cycle_count <= 0;
                if (time_left > 0) begin
                    time_left <= time_left - 1;
                    done      <= 0;
                end else begin
                    active    <= 0;
                    done      <= 1; // Timer has finished
                end
            end else begin
                cycle_count <= cycle_count + 1;
                done        <= 0;
            end
        end else begin
            done <= 0;
        end
    end

endmodule
