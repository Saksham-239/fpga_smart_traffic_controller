// =========================================================================
// Project:     FPGA Smart Traffic Light Controller
// File:        debounce.v
// Description: Debounce filter to clean mechanical switch contact bounce.
//              Generates a single clean pulse upon button press.
// Board:       Intel/Altera DE2-115 (Cyclone IV E EP4CE115F29C7)
// Author:      Saksham Arora (24BEC0185)
// Course:      Digital System Design Lab (BECE102P)
// Instructor:  Dr. Vishal Gupta
// =========================================================================

module debounce (
    input  wire  clk,
    input  wire  reset,
    input  wire  noisy,  // Raw, noisy mechanical button input
    output reg   clean  // Filtered, single clock-cycle pulse output on rising edge
);

    parameter integer DELAY = 1000000; // Delay period (in clock cycles) to filter bounce
    
    reg [19:0] count;
    reg        new_val;
    reg        prev_val;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count    <= 0;
            new_val  <= 0;
            prev_val <= 0;
            clean    <= 0;
        end else begin
            if (noisy != new_val) begin
                new_val <= noisy;
                count   <= 0;
                clean   <= 0;
            end else if (count >= DELAY) begin
                prev_val <= new_val;
                // Generate a one-cycle pulse on a rising edge (0 -> 1 transition)
                clean    <= new_val & ~prev_val;
            end else begin
                count <= count + 1;
                clean <= 0;
            end
        end
    end

endmodule
