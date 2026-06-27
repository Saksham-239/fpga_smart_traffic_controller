// =========================================================================
// Project:     FPGA Smart Traffic Light Controller
// File:        seven_seg_decoder.v
// Description: Decodes a 4-bit binary digit (0-9) to active-low 7-segment
//              display control patterns for Altera DE2-115 boards.
// Board:       Intel/Altera DE2-115 (Cyclone IV E EP4CE115F29C7)
// Author:      Saksham Arora (24BEC0185)
// Course:      Digital System Design Lab (BECE102P)
// Instructor:  Dr. Vishal Gupta
// =========================================================================

module seven_seg_decoder (
    input  wire [3:0] digit, // 4-bit binary value (0 to 9)
    output reg  [6:0] seg    // Active-low segment signals [6:a, 5:b, 4:c, 3:d, 2:e, 1:f, 0:g]
);

    always @(*) begin
        case (digit)
            // Pin mapping: seg[0]:g, seg[1]:f, seg[2]:e, seg[3]:d, seg[4]:c, seg[5]:b, seg[6]:a
            // A '0' turns on the LED segment, a '1' turns it off
            4'd0:    seg = 7'b1000000; // Display "0"
            4'd1:    seg = 7'b1111001; // Display "1"
            4'd2:    seg = 7'b0100100; // Display "2"
            4'd3:    seg = 7'b0110000; // Display "3"
            4'd4:    seg = 7'b0011001; // Display "4"
            4'd5:    seg = 7'b0010010; // Display "5"
            4'd6:    seg = 7'b0000010; // Display "6"
            4'd7:    seg = 7'b1111000; // Display "7"
            4'd8:    seg = 7'b0000000; // Display "8"
            4'd9:    seg = 7'b0011000; // Display "9"
            default: seg = 7'b1111111; // Blank display
        endcase
    end

endmodule
