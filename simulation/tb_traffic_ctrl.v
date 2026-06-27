// =========================================================================
// Project:     FPGA Smart Traffic Light Controller
// File:        tb_traffic_ctrl.v
// Description: Comprehensive testbench for top-level traffic_ctrl simulation.
//              Applies parameters to scale down the clock dividers for high-speed
//              RTL simulation. Simulates FSM cycling, sensor extensions,
//              pedestrian requests, emergency override, and night mode.
// Simulator:   ModelSim / Icarus Verilog
// Author:      Saksham Arora (24BEC0185)
// Course:      Digital System Design Lab (BECE102P)
// Instructor:  Dr. Vishal Gupta
// =========================================================================

`timescale 1ns / 1ps

module tb_traffic_ctrl;

    // Inputs to UUT
    reg         tb_clk;
    reg  [1:0]  tb_key;
    reg  [7:0]  tb_sw;

    // Outputs from UUT
    wire [15:0] tb_ledr;
    wire [6:0]  tb_hex0;

    // Simulation timing parameters (scaled down for rapid simulation)
    // 50 MHz clock has a 20ns period (10ns high, 10ns low)
    localparam CLK_PERIOD = 20; 
    localparam SIM_DEBOUNCE_DELAY        = 5;   // 5 clock cycles debounce filter
    localparam SIM_TIMER_CYCLES_PER_SEC  = 50;  // 1 simulated second = 50 clock cycles (1 us)
    localparam SIM_FLASH_HALF_PERIOD_CYC = 25;  // Night flash half period = 25 cycles (0.5 us)

    // Instantiate Unit Under Test (UUT) with speedup parameters
    traffic_ctrl #(
        .DEBOUNCE_DELAY(SIM_DEBOUNCE_DELAY),
        .TIMER_CYCLES_PER_SEC(SIM_TIMER_CYCLES_PER_SEC),
        .FLASH_HALF_PERIOD_CYC(SIM_FLASH_HALF_PERIOD_CYC)
    ) uut (
        .CLOCK_50(tb_clk),
        .KEY(tb_key),
        .SW(tb_sw),
        .LEDR(tb_ledr),
        .HEX0(tb_hex0)
    );

    // Clock generator (50 MHz)
    always begin
        #(CLK_PERIOD/2) tb_clk = ~tb_clk;
    end

    // Helper task to format output and trace traffic light states
    task display_lights;
        begin
            $display("[Time %0t ns] R0:%s%s%s | R1:%s%s%s | R2:%s%s%s | R3:%s%s%s | Ped:%s%s | Hex0:%b", 
                $time,
                tb_ledr[2] ? "G" : "-", tb_ledr[1] ? "Y" : "-", tb_ledr[0] ? "R" : "-",
                tb_ledr[5] ? "G" : "-", tb_ledr[4] ? "Y" : "-", tb_ledr[3] ? "R" : "-",
                tb_ledr[8] ? "G" : "-", tb_ledr[7] ? "Y" : "-", tb_ledr[6] ? "R" : "-",
                tb_ledr[11] ? "G" : "-", tb_ledr[10] ? "Y" : "-", tb_ledr[9] ? "R" : "-",
                tb_ledr[13] ? "G" : "-", tb_ledr[12] ? "R" : "-",
                tb_hex0
            );
        end
    endtask

    initial begin
        // Initialize Inputs
        tb_clk = 0;
        tb_sw  = 8'h00;
        tb_key = 2'b11; // Active-low buttons. 2'b11 means neither KEY[1] nor KEY[0] is pressed.

        $display("========================================================================");
        $display("              FPGA Smart Traffic Light Controller Testbench              ");
        $display("========================================================================");

        // 1. Apply Reset
        $display("\n--- Step 1: System Reset ---");
        tb_key[1] = 0; // Assert Active-low Reset (KEY[1])
        #(CLK_PERIOD * 5);
        tb_key[1] = 1; // De-assert Reset
        $display("System released from reset.");
        display_lights();

        // 2. Observe normal operation cycles
        $display("\n--- Step 2: Observing Normal Cycle Transitions ---");
        // Road 0 Green Base is 9 seconds. Let's wait for Road 0 Green to expire.
        // It should take (9 sec * 50 cycles/sec * 20ns/cycle) = 9000 ns.
        #(CLK_PERIOD * 50 * 5); // Wait 5 simulated seconds
        display_lights();
        #(CLK_PERIOD * 50 * 5); // Wait remaining Road 0 green + yellow + red transition
        display_lights();

        // 3. Test Vehicle Sensor Extension on Road 1
        $display("\n--- Step 3: Testing Adaptive Sensor Extension on Road 1 ---");
        // Wait until Road 1 green starts.
        // Let's monitor outputs until Road 1 Green (LEDR[5] = 1) turns on.
        while (tb_ledr[5] !== 1'b1) begin
            #(CLK_PERIOD);
        end
        $display("Road 1 Green detected. Activating Road 1 Vehicle Sensor (SW[1] = 1)...");
        tb_sw[1] = 1; // Activate Road 1 sensor
        
        // Wait 8 simulated seconds. Base is 7, extension should add 2, making it 9s.
        #(CLK_PERIOD * 50 * 8);
        $display("After 8 seconds, Road 1 Green should still be active due to extension:");
        display_lights();
        
        tb_sw[1] = 0; // Clear sensor
        #(CLK_PERIOD * 50 * 3); // Wait for transition to Road 1 Yellow and then Red
        display_lights();

        // 4. Test Pedestrian Crossing request
        $display("\n--- Step 4: Testing Pedestrian Crossing Request ---");
        // Pulse pedestrian request button KEY[0] (active-low)
        #(CLK_PERIOD * 10);
        tb_key[0] = 0; // Press button
        #(CLK_PERIOD * SIM_DEBOUNCE_DELAY * 2); // Wait to clear debounce filter
        tb_key[0] = 1; // Release button
        $display("Pedestrian button pulsed and debounced.");
        
        // The FSM completes the cycle up to Road 3 then serves the pedestrian crossing.
        // Let's wait until Pedestrian Green (LEDR[13] = 1) turns on.
        while (tb_ledr[13] !== 1'b1) begin
            #(CLK_PERIOD);
        end
        $display("Pedestrian Green light active!");
        display_lights();
        
        #(CLK_PERIOD * 50 * 4); // Wait mid-cross
        display_lights();
        
        #(CLK_PERIOD * 50 * 5); // Wait until pedestrian phase ends and transitions back
        $display("Pedestrian crossing completed, transitioning back to Road 0 Green:");
        display_lights();

        // 5. Test Emergency Priority Override
        $display("\n--- Step 5: Testing Emergency Priority Switch Override ---");
        #(CLK_PERIOD * 50 * 2);
        $display("Activating Emergency Override (SW[4] = 1)...");
        tb_sw[4] = 1; // Emergency on
        #(CLK_PERIOD * 5); // Give FSM a few cycles to respond
        $display("Emergency State lights:");
        display_lights();
        
        #(CLK_PERIOD * 50 * 5); // Hold emergency for 5 simulated seconds
        $display("De-activating Emergency Override (SW[4] = 0)...");
        tb_sw[4] = 0; // Emergency off
        #(CLK_PERIOD * 10);
        display_lights();

        // 6. Test Night Caution Mode
        $display("\n--- Step 6: Testing Night Caution Flash Mode ---");
        #(CLK_PERIOD * 50 * 2);
        $display("Activating Night Mode (SW[5] = 1)...");
        tb_sw[5] = 1; // Night mode on
        
        // Wait and observe yellow light blinking
        #(CLK_PERIOD * SIM_FLASH_HALF_PERIOD_CYC * 2);
        display_lights();
        #(CLK_PERIOD * SIM_FLASH_HALF_PERIOD_CYC * 2);
        display_lights();
        #(CLK_PERIOD * SIM_FLASH_HALF_PERIOD_CYC * 2);
        display_lights();
        
        $display("De-activating Night Mode (SW[5] = 0)...");
        tb_sw[5] = 0;
        #(CLK_PERIOD * 10);
        display_lights();
        
        $display("\n========================================================================");
        $display("                         Simulation Completed!                          ");
        $display("========================================================================");
        $finish;
    end

endmodule
