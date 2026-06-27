// =========================================================================
// Project:     FPGA Smart Traffic Light Controller
// File:        traffic_fsm.v
// Description: Central FSM controller governing light sequences, sensor-based
//              green time extensions, emergency override, pedestrian request,
//              and night caution mode.
// Board:       Intel/Altera DE2-115 (Cyclone IV E EP4CE115F29C7)
// Author:      Saksham Arora (24BEC0185)
// Course:      Digital System Design Lab (BECE102P)
// Instructor:  Dr. Vishal Gupta
// =========================================================================

module traffic_fsm (
    input  wire        clk,
    input  wire        reset,
    input  wire        ped_button,    // Pulsed pedestrian crossing button input
    input  wire [3:0]  road_sensor,   // Adaptive traffic flow sensors: [3]:Road 3, [2]:Road 2, [1]:Road 1, [0]:Road 0
    input  wire        emergency,     // High forces system into Emergency Mode (Main Road green, all others red)
    input  wire        night_mode,    // High forces system into Night Caution Mode (Flashing yellow on Road 0, red on others)
    
    // Road lights output signals
    output reg         road0_red,   output reg         road0_yellow,   output reg         road0_green,
    output reg         road1_red,   output reg         road1_yellow,   output reg         road1_green,
    output reg         road2_red,   output reg         road2_yellow,   output reg         road2_green,
    output reg         road3_red,   output reg         road3_yellow,   output reg         road3_green,
    output reg         ped_red,     output reg         ped_green,
    
    // Timer handshake signals
    output reg         start_timer,
    output reg  [3:0]  load_value,
    input  wire        timer_done
);

    // FSM State Encoding
    localparam [4:0]
        ROAD0_GREEN  = 5'd0,
        ROAD0_YELLOW = 5'd1,
        ALL_RED_01   = 5'd2,
        ROAD1_GREEN  = 5'd3,
        ROAD1_YELLOW = 5'd4,
        ALL_RED_12   = 5'd5,
        ROAD2_GREEN  = 5'd6,
        ROAD2_YELLOW = 5'd7,
        ALL_RED_23   = 5'd8,
        ROAD3_GREEN  = 5'd9,
        ROAD3_YELLOW = 5'd10,
        ALL_RED_30   = 5'd11,
        PED_CROSS    = 5'd12,
        PED_ALL_RED  = 5'd13,
        EMERGENCY    = 5'd14,
        NIGHT_FLASH  = 5'd15;

    // Timing Configuration Parameters (in seconds)
    parameter [3:0] ROAD0_GREEN_BASE  = 4'd9;
    parameter [3:0] ROAD1_GREEN_BASE  = 4'd7;
    parameter [3:0] ROAD2_GREEN_BASE  = 4'd6;
    parameter [3:0] ROAD3_GREEN_BASE  = 4'd7;
    
    // Extensions added if corresponding sensor is active (high)
    parameter [3:0] ROAD0_GREEN_EXT   = 4'd2;
    parameter [3:0] ROAD1_GREEN_EXT   = 4'd2;
    parameter [3:0] ROAD2_GREEN_EXT   = 4'd2;
    parameter [3:0] ROAD3_GREEN_EXT   = 4'd2;
    
    // Common timing parameters
    parameter [3:0] ROAD_YELLOW_TIME   = 4'd3;
    parameter [3:0] PED_TIME           = 4'd7;
    parameter [3:0] ALL_RED_TIME       = 4'd1;
    
    // Flash rate constant (25,000,000 cycles = 0.5s on a 50MHz clock)
    parameter integer FLASH_HALF_PERIOD_CYC = 25000000;

    // FSM Internal State Registers
    reg [4:0]  state, prev_state;
    reg        ped_request;
    reg [31:0] flash_counter;
    reg        flash_state;

    // State Transition Block (Synchronous reset and state updates)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= ROAD0_GREEN;
            prev_state <= 5'h1F; // Dummy initial state
        end else begin
            prev_state <= state;
            if (emergency) begin
                state <= EMERGENCY;
            end else if (night_mode) begin
                state <= NIGHT_FLASH;
            end else if (timer_done) begin
                case (state)
                    ROAD0_GREEN:  state <= ROAD0_YELLOW;
                    ROAD0_YELLOW: state <= ALL_RED_01;
                    ALL_RED_01:   state <= ROAD1_GREEN;
                    
                    ROAD1_GREEN:  state <= ROAD1_YELLOW;
                    ROAD1_YELLOW: state <= ALL_RED_12;
                    ALL_RED_12:   state <= ROAD2_GREEN;
                    
                    ROAD2_GREEN:  state <= ROAD2_YELLOW;
                    ROAD2_YELLOW: state <= ALL_RED_23;
                    ALL_RED_23:   state <= ROAD3_GREEN;
                    
                    ROAD3_GREEN:  state <= ROAD3_YELLOW;
                    ROAD3_YELLOW: state <= ALL_RED_30;
                    ALL_RED_30:   state <= (ped_request ? PED_CROSS : ROAD0_GREEN);
                    
                    PED_CROSS:    state <= PED_ALL_RED;
                    PED_ALL_RED:  state <= ROAD0_GREEN;
                    default:      state <= ROAD0_GREEN;
                endcase
            end else begin
                // Return to normal sequence if Emergency or Night Mode is deactivated
                if (!emergency && prev_state == EMERGENCY && state == EMERGENCY) begin
                    state <= ALL_RED_01;
                end
                if (!night_mode && prev_state == NIGHT_FLASH && state == NIGHT_FLASH) begin
                    state <= ALL_RED_01;
                end
            end
        end
    end

    // Latch Pedestrian Button Press Request
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ped_request <= 1'b0;
        end else begin
            if (ped_button) begin
                ped_request <= 1'b1;
            end
            // Clear request latch once the pedestrian crossing phase is active
            if (state == PED_CROSS && prev_state != PED_CROSS) begin
                ped_request <= 1'b0;
            end
        end
    end

    // Combinational Output Logic and Timer Loading Block
    always @(*) begin
        // Default assignment for safety: All roads red, ped red, timer idle
        road0_red = 0; road0_yellow = 0; road0_green = 0;
        road1_red = 0; road1_yellow = 0; road1_green = 0;
        road2_red = 0; road2_yellow = 0; road2_green = 0;
        road3_red = 0; road3_yellow = 0; road3_green = 0;
        ped_red   = 0; ped_green    = 0;
        start_timer = 0; load_value = 0;

        case (state)
            ROAD0_GREEN: begin
                road0_green = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value  = ROAD0_GREEN_BASE + (road_sensor[0] ? ROAD0_GREEN_EXT : 0);
                if (load_value > 9) load_value = 9; // Cap timer representation at single digit (9)
                if (state != prev_state) start_timer = 1;
            end
            
            ROAD0_YELLOW: begin
                road0_yellow = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value   = ROAD_YELLOW_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            ALL_RED_01: begin
                road0_red = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value = ALL_RED_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            ROAD1_GREEN: begin
                road1_green = 1; road0_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value  = ROAD1_GREEN_BASE + (road_sensor[1] ? ROAD1_GREEN_EXT : 0);
                if (load_value > 9) load_value = 9;
                if (state != prev_state) start_timer = 1;
            end
            
            ROAD1_YELLOW: begin
                road1_yellow = 1; road0_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value   = ROAD_YELLOW_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            ALL_RED_12: begin
                road0_red = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value = ALL_RED_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            ROAD2_GREEN: begin
                road2_green = 1; road0_red = 1; road1_red = 1; road3_red = 1; ped_red = 1;
                load_value  = ROAD2_GREEN_BASE + (road_sensor[2] ? ROAD2_GREEN_EXT : 0);
                if (load_value > 9) load_value = 9;
                if (state != prev_state) start_timer = 1;
            end
            
            ROAD2_YELLOW: begin
                road2_yellow = 1; road0_red = 1; road1_red = 1; road3_red = 1; ped_red = 1;
                load_value   = ROAD_YELLOW_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            ALL_RED_23: begin
                road0_red = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value = ALL_RED_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            ROAD3_GREEN: begin
                road3_green = 1; road0_red = 1; road1_red = 1; road2_red = 1; ped_red = 1;
                load_value  = ROAD3_GREEN_BASE + (road_sensor[3] ? ROAD3_GREEN_EXT : 0);
                if (load_value > 9) load_value = 9;
                if (state != prev_state) start_timer = 1;
            end
            
            ROAD3_YELLOW: begin
                road3_yellow = 1; road0_red = 1; road1_red = 1; road2_red = 1; ped_red = 1;
                load_value   = ROAD_YELLOW_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            ALL_RED_30: begin
                road0_red = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value = ALL_RED_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            PED_CROSS: begin
                road0_red = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_green = 1;
                load_value = PED_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            PED_ALL_RED: begin
                road0_red = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value = ALL_RED_TIME;
                if (state != prev_state) start_timer = 1;
            end
            
            EMERGENCY: begin
                // In emergency override, force Road 0 to Green and all other signals to Red.
                // Timer is not used during emergency override.
                road0_green = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
            end
            
            NIGHT_FLASH: begin
                // Flashing yellow warning on Road 0; others remain in red caution state
                road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                if (flash_state) begin
                    road0_yellow = 1;
                end
            end
            
            default: begin
                road0_green = 1; road1_red = 1; road2_red = 1; road3_red = 1; ped_red = 1;
                load_value  = ROAD0_GREEN_BASE;
                if (state != prev_state) start_timer = 1;
            end
        endcase
    end

    // Flashing Yellow Clock Divider for Night Mode
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            flash_counter <= 0;
            flash_state   <= 0;
        end else begin
            if (state == NIGHT_FLASH) begin
                if (flash_counter >= FLASH_HALF_PERIOD_CYC - 1) begin
                    flash_counter <= 0;
                    flash_state   <= ~flash_state;
                end else begin
                    flash_counter <= flash_counter + 1;
                end
            end else begin
                flash_counter <= 0;
                flash_state   <= 0;
            end
        end
    end

endmodule
