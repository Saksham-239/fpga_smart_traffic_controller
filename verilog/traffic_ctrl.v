// =========================================================================
// Project:     FPGA Smart Traffic Light Controller
// File:        traffic_ctrl.v
// Description: Top-level module for the 4-way adaptive traffic controller.
//              Integrates the main FSM, countdown timer, pedestrian
//              button debouncer, and 7-segment display decoder.
// Board:       Intel/Altera DE2-115 (Cyclone IV E EP4CE115F29C7)
// Author:      Saksham Arora (24BEC0185)
// Course:      Digital System Design Lab (BECE102P)
// Instructor:  Dr. Vishal Gupta
// =========================================================================

module traffic_ctrl #(
    parameter integer DEBOUNCE_DELAY        = 1000000,
    parameter integer TIMER_CYCLES_PER_SEC  = 50000000,
    parameter integer FLASH_HALF_PERIOD_CYC = 25000000
)(
    input  wire        CLOCK_50,  // 50 MHz system clock
    input  wire [1:0]  KEY,       // KEY[1]: Active-low Reset, KEY[0]: Pedestrian crossing request button
    input  wire [7:0]  SW,        // SW[3:0]: Road sensors, SW[4]: Emergency mode, SW[5]: Night mode
    output wire [15:0] LEDR,      // LEDR[13:0]: Traffic lights, LEDR[14]: Emergency indicator, LEDR[15]: Night mode indicator
    output wire [6:0]  HEX0       // HEX0[6:0]: 7-Segment display output for countdown timer
);

    // Internal signal declarations
    wire       clk;
    wire       reset;
    wire       ped_debounced;
    wire       timer_done;
    wire       start_timer;
    wire [3:0] load_value;
    wire [3:0] time_left;
    
    // Road light state lines
    wire       road0_red, road0_yellow, road0_green;
    wire       road1_red, road1_yellow, road1_green;
    wire       road2_red, road2_yellow, road2_green;
    wire       road3_red, road3_yellow, road3_green;
    wire       ped_red, ped_green;

    // Clock and Reset assignment
    assign clk   = CLOCK_50;
    assign reset = ~KEY[1];  // Convert active-low key input to active-high internal reset

    // Instantiate Pedestrian Button Debouncer (Mechanical Key Filter)
    debounce #(.DELAY(DEBOUNCE_DELAY)) u_debounce (
        .clk(clk),
        .reset(reset),
        .noisy(~KEY[0]), // KEY[0] is active-low; invert to active-high noisy input
        .clean(ped_debounced)
    );

    // Instantiate Central Finite State Machine (FSM)
    traffic_fsm #(.FLASH_HALF_PERIOD_CYC(FLASH_HALF_PERIOD_CYC)) u_fsm (
        .clk(clk),
        .reset(reset),
        .ped_button(ped_debounced),
        .road_sensor({SW[3], SW[2], SW[1], SW[0]}), // Sw[3:0] correspond to vehicle presence on Roads 3, 2, 1, 0
        .emergency(SW[4]),                          // Emergency mode switch
        .night_mode(SW[5]),                         // Night mode switch
        .road0_red(road0_red),       .road0_yellow(road0_yellow),       .road0_green(road0_green),
        .road1_red(road1_red),       .road1_yellow(road1_yellow),       .road1_green(road1_green),
        .road2_red(road2_red),       .road2_yellow(road2_yellow),       .road2_green(road2_green),
        .road3_red(road3_red),       .road3_yellow(road3_yellow),       .road3_green(road3_green),
        .ped_red(ped_red),           .ped_green(ped_green),
        .start_timer(start_timer),
        .load_value(load_value),
        .timer_done(timer_done)
    );

    // Instantiate Countdown Timer
    countdown_timer #(.CYCLES_PER_SEC(TIMER_CYCLES_PER_SEC)) u_timer (
        .clk(clk),
        .reset(reset),
        .start(start_timer),
        .load_val(load_value),
        .time_left(time_left),
        .done(timer_done)
    );

    // Instantiate Seven-Segment Display Decoder
    seven_seg_decoder u_seg (
        .digit(time_left),
        .seg(HEX0)
    );

    // Physical board layout LED mapping
    assign LEDR[0]  = road0_red;
    assign LEDR[1]  = road0_yellow;
    assign LEDR[2]  = road0_green;
    
    assign LEDR[3]  = road1_red;
    assign LEDR[4]  = road1_yellow;
    assign LEDR[5]  = road1_green;
    
    assign LEDR[6]  = road2_red;
    assign LEDR[7]  = road2_yellow;
    assign LEDR[8]  = road2_green;
    
    assign LEDR[9]  = road3_red;
    assign LEDR[10] = road3_yellow;
    assign LEDR[11] = road3_green;
    
    assign LEDR[12] = ped_red;
    assign LEDR[13] = ped_green;
    
    assign LEDR[14] = SW[4]; // Reflect Emergency switch status on LEDR14
    assign LEDR[15] = SW[5]; // Reflect Night Mode switch status on LEDR15

endmodule
