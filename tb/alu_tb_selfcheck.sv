// ============================================================
// File    : tb/alu_tb_selfcheck.sv
// Project : 4-bit ALU Verification
// Author  : [Your Name]
// Date    : 2025
//
// Description:
//   Self-checking testbench for alu.sv.
//   Verification flow:
//     Phase 1 — Directed tests  (hand-crafted corner cases)
//     Phase 2 — Randomized tests (golden model comparison)
//     Phase 3 — Summary report  (scoreboard + coverage)
//
//   The golden model is an independent implementation of the ALU
//   specification, written separately from the RTL.  Any mismatch
//   between DUT and golden model flags a real bug.
//
//   Functional coverage is tracked manually using bit-flags so the
//   file stays in plain Verilog-compatible SystemVerilog without
//   needing a UVM or coverage-group-capable license.
// ============================================================

`timescale 1ns / 1ps

module alu_tb_selfcheck;

    // ============================================================
    // 1. SIGNAL DECLARATIONS
    // ============================================================

    // Testbench drives these (logic, not wire, because we assign in initial)
    logic [3:0] A;
    logic [3:0] B;
    logic [2:0] op;

    // DUT drives these
    logic [3:0] result;
    logic       carry;
    logic       zero;
    logic       overflow;

    // ============================================================
    // 2. DUT INSTANTIATION
    // ============================================================
    alu dut (
        .A        (A),
        .B        (B),
        .op       (op),
        .result   (result),
        .carry    (carry),
        .zero     (zero),
        .overflow (overflow)
    );

    // ============================================================
    // 3. ASSERTION CHECKER INSTANTIATION
    //
    //   alu_sva monitors all DUT outputs in parallel with the
    //   testbench.  Any assertion violation prints an error and
    //   helps pinpoint bugs at the exact simulation moment.
    //
    //   In a real project this would be done with a SystemVerilog
    //   'bind' statement.  We instantiate it directly here for
    //   simplicity and ModelSim compatibility.
    // ============================================================
    alu_sva u_sva (
        .A        (A),
        .B        (B),
        .op       (op),
        .result   (result),
        .carry    (carry),
        .zero     (zero),
        .overflow (overflow)
    );

    // ============================================================
    // 4. SCOREBOARD COUNTERS
    // ============================================================
    int unsigned total_tests  = 0;
    int unsigned total_pass   = 0;
    int unsigned total_fail   = 0;

    // ============================================================
    // 5. FUNCTIONAL COVERAGE TRACKING
    //
    //    We track coverage manually with simple flags.
    //    Each flag is set the first time a condition is observed.
    //    At the end we report which ones were never hit.
    // ============================================================

    // op_seen[i] = 1 when opcode i has been exercised at least once
    logic [7:0] op_seen = 8'h00;

    // Flag coverage
    logic cov_carry_high    = 1'b0;   // carry == 1 seen
    logic cov_zero_high     = 1'b0;   // zero  == 1 seen
    logic cov_overflow_high = 1'b0;   // overflow == 1 seen

    // Operand boundary coverage
    logic cov_A_zero = 1'b0;   // A == 4'h0
    logic cov_A_ones = 1'b0;   // A == 4'hF
    logic cov_B_zero = 1'b0;   // B == 4'h0
    logic cov_B_ones = 1'b0;   // B == 4'hF
    logic cov_A_eq_B = 1'b0;   // A == B

    // ============================================================
    // 5. GOLDEN MODEL FUNCTION
    //
    //    This function computes the EXPECTED outputs using the
    //    specification, NOT by reading the DUT RTL.
    //    It is the ground truth for all comparison checks.
    //
    //    Using an automatic function lets us call it inline with
    //    output values returned via a packed struct-style approach.
    //    Since SV functions return one value, we use a task instead
    //    so we can populate four output variables.
    // ============================================================
    task automatic golden_model (
        input  logic [3:0] gA,
        input  logic [3:0] gB,
        input  logic [2:0] gop,
        output logic [3:0] exp_result,
        output logic       exp_carry,
        output logic       exp_zero,
        output logic       exp_overflow
    );
        logic [4:0] tmp;
        begin
            // Safe defaults
            exp_carry    = 1'b0;
            exp_overflow = 1'b0;
            tmp          = 5'b00000;

            case (gop)
                3'b000: begin // ADD
                    tmp          = {1'b0, gA} + {1'b0, gB};
                    exp_result   = tmp[3:0];
                    exp_carry    = tmp[4];
                    exp_overflow = (~gA[3] & ~gB[3] &  exp_result[3])
                                 | ( gA[3] &  gB[3] & ~exp_result[3]);
                end
                3'b001: begin // SUB
                    tmp          = {1'b0, gA} - {1'b0, gB};
                    exp_result   = tmp[3:0];
                    exp_carry    = tmp[4];
                    exp_overflow = (~gA[3] &  gB[3] &  exp_result[3])
                                 | ( gA[3] & ~gB[3] & ~exp_result[3]);
                end
                3'b010: exp_result = gA & gB;   // AND
                3'b011: exp_result = gA | gB;   // OR
                3'b100: exp_result = gA ^ gB;   // XOR
                3'b101: exp_result = ~gA;        // NOT
                3'b110: begin                    // SHL
                    exp_result = gA << 1;
                    exp_carry  = gA[3];
                end
                3'b111: begin                    // SHR
                    exp_result = gA >> 1;
                    exp_carry  = gA[0];
                end
                default: exp_result = 4'b0000;
            endcase

            exp_zero = (exp_result == 4'b0000);
        end
    endtask

    // ============================================================
    // 6. CHECK TASK
    //
    //    Calls golden_model, compares to DUT outputs, updates
    //    the scoreboard, and prints a message on any mismatch.
    //    Also updates functional coverage flags.
    // ============================================================
    task automatic check_outputs (
        input logic [3:0]  in_A,
        input logic [3:0]  in_B,
        input logic [2:0]  in_op,
        input string       test_label   // e.g. "DT-001" or "RND"
    );
        logic [3:0] exp_r;
        logic       exp_c, exp_z, exp_ov;
        begin
            // --- Apply stimulus to DUT ---
            A  = in_A;
            B  = in_B;
            op = in_op;
            #10; // Wait for combinational logic to settle (10 ns)

            // --- Compute expected values ---
            golden_model(in_A, in_B, in_op, exp_r, exp_c, exp_z, exp_ov);

            // --- Update scoreboard ---
            total_tests++;

            // --- Update functional coverage ---
            op_seen[in_op]  = 1'b1;
            if (carry)    cov_carry_high    = 1'b1;
            if (zero)     cov_zero_high     = 1'b1;
            if (overflow) cov_overflow_high = 1'b1;
            if (in_A == 4'h0) cov_A_zero   = 1'b1;
            if (in_A == 4'hF) cov_A_ones   = 1'b1;
            if (in_B == 4'h0) cov_B_zero   = 1'b1;
            if (in_B == 4'hF) cov_B_ones   = 1'b1;
            if (in_A == in_B) cov_A_eq_B   = 1'b1;

            // --- Compare DUT output vs golden model ---
            if (result   !== exp_r  ||
                carry    !== exp_c  ||
                zero     !== exp_z  ||
                overflow !== exp_ov)
            begin
                // ---- MISMATCH: print detailed debug info ----
                $display("[FAIL] %-8s | op=%03b A=%0h B=%0h | DUT: res=%0h c=%0b z=%0b ov=%0b | EXP: res=%0h c=%0b z=%0b ov=%0b",
                    test_label, in_op, in_A, in_B,
                    result,   carry,   zero,   overflow,
                    exp_r,    exp_c,   exp_z,  exp_ov);
                total_fail++;
            end else begin
                // ---- MATCH: only print for directed tests ----
                if (test_label.substr(0,1) == "D")
                    $display("[PASS] %-8s | op=%03b A=%0h B=%0h -> result=%0h carry=%0b zero=%0b overflow=%0b",
                        test_label, in_op, in_A, in_B, result, carry, zero, overflow);
                total_pass++;
            end
        end
    endtask

    // ============================================================
    // 7. COVERAGE REPORT TASK
    // ============================================================
    task print_coverage_report;
        int unsigned ops_hit;
        int unsigned i;
        begin
            ops_hit = 0;
            for (i = 0; i < 8; i++)
                if (op_seen[i]) ops_hit++;

            $display("");
            $display("==============================================");
            $display("         FUNCTIONAL COVERAGE REPORT          ");
            $display("==============================================");
            $display("Opcodes exercised : %0d / 8", ops_hit);
            $display("  ADD  (op=000)   : %s", op_seen[0] ? "HIT" : "MISS ***");
            $display("  SUB  (op=001)   : %s", op_seen[1] ? "HIT" : "MISS ***");
            $display("  AND  (op=010)   : %s", op_seen[2] ? "HIT" : "MISS ***");
            $display("  OR   (op=011)   : %s", op_seen[3] ? "HIT" : "MISS ***");
            $display("  XOR  (op=100)   : %s", op_seen[4] ? "HIT" : "MISS ***");
            $display("  NOT  (op=101)   : %s", op_seen[5] ? "HIT" : "MISS ***");
            $display("  SHL  (op=110)   : %s", op_seen[6] ? "HIT" : "MISS ***");
            $display("  SHR  (op=111)   : %s", op_seen[7] ? "HIT" : "MISS ***");
            $display("");
            $display("Flag coverage:");
            $display("  carry    == 1   : %s", cov_carry_high    ? "HIT" : "MISS ***");
            $display("  zero     == 1   : %s", cov_zero_high     ? "HIT" : "MISS ***");
            $display("  overflow == 1   : %s", cov_overflow_high ? "HIT" : "MISS ***");
            $display("");
            $display("Operand boundary coverage:");
            $display("  A == 4h0        : %s", cov_A_zero ? "HIT" : "MISS ***");
            $display("  A == 4hF        : %s", cov_A_ones ? "HIT" : "MISS ***");
            $display("  B == 4h0        : %s", cov_B_zero ? "HIT" : "MISS ***");
            $display("  B == 4hF        : %s", cov_B_ones ? "HIT" : "MISS ***");
            $display("  A == B          : %s", cov_A_eq_B ? "HIT" : "MISS ***");
            $display("==============================================");
        end
    endtask

    // ============================================================
    // 8. FINAL SUMMARY TASK
    // ============================================================
    task print_final_summary;
        begin
            $display("");
            $display("==============================================");
            $display("            SIMULATION SUMMARY               ");
            $display("==============================================");
            $display("Total vectors   : %0d", total_tests);
            $display("Passed          : %0d", total_pass);
            $display("Failed          : %0d", total_fail);
            $display("----------------------------------------------");
            if (total_fail == 0)
                $display(">>> ALL TESTS PASSED - DUT IS CORRECT <<<");
            else
                $display(">>> %0d FAILURE(S) FOUND - CHECK LOG ABOVE <<<", total_fail);
            $display("==============================================");
        end
    endtask

    // ============================================================
    // 9. MAIN STIMULUS — INITIAL BLOCK
    // ============================================================
    initial begin

        // Give DUT a defined starting state
        A  = 4'h0;
        B  = 4'h0;
        op = 3'b000;
        #5;

        // ----------------------------------------------------------
        // PHASE 1 : DIRECTED TESTS
        //
        //   Each test targets a specific requirement from the
        //   Verification Plan.  The label "DT-NNN" maps back to the
        //   VPlan table so each test is traceable to a requirement.
        //
        //   Test format:
        //     check_outputs(A, B, op, label);
        // ----------------------------------------------------------

        $display("");
        $display("==============================================");
        $display("   ALU SELF-CHECKING TESTBENCH - START       ");
        $display("==============================================");
        $display("");
        $display("--- PHASE 1: DIRECTED TESTS ---");

        // ---- ADD operation ----
        // DT-001: Simple addition, no flags
        check_outputs(4'h3, 4'h5, 3'b000, "DT-001");
        // DT-002: ADD causing carry out  (0xF + 0x1 = 0x10 -> result=0, carry=1, zero=1)
        check_outputs(4'hF, 4'h1, 3'b000, "DT-002");
        // DT-003: ADD causing signed overflow (7 + 1 = 8; in 4-bit signed: 7+1 wraps to -8)
        check_outputs(4'h7, 4'h1, 3'b000, "DT-003");
        // DT-004: ADD with A=0
        check_outputs(4'h0, 4'h5, 3'b000, "DT-004");
        // DT-005: ADD both zero -> zero flag
        check_outputs(4'h0, 4'h0, 3'b000, "DT-005");
        // DT-006: ADD both max -> double carry + zero
        check_outputs(4'hF, 4'hF, 3'b000, "DT-006");

        // ---- SUB operation ----
        // DT-007: Normal subtraction
        check_outputs(4'h8, 4'h3, 3'b001, "DT-007");
        // DT-008: SUB with borrow (0 - 1 = borrow, result = 0xF)
        check_outputs(4'h0, 4'h1, 3'b001, "DT-008");
        // DT-009: A == B -> zero result
        check_outputs(4'h5, 4'h5, 3'b001, "DT-009");
        // DT-010: Signed overflow: -8 - 1 = -9 (cannot represent, overflow)
        check_outputs(4'h8, 4'h1, 3'b001, "DT-010");

        // ---- AND operation ----
        // DT-011: AND of complementary values -> zero
        check_outputs(4'h5, 4'hA, 3'b010, "DT-011");
        // DT-012: AND all ones -> A
        check_outputs(4'h7, 4'hF, 3'b010, "DT-012");
        // DT-013: AND with zero -> zero
        check_outputs(4'hF, 4'h0, 3'b010, "DT-013");

        // ---- OR operation ----
        // DT-014: OR of complementary -> all ones
        check_outputs(4'h5, 4'hA, 3'b011, "DT-014");
        // DT-015: OR with zero -> A
        check_outputs(4'h7, 4'h0, 3'b011, "DT-015");

        // ---- XOR operation ----
        // DT-016: XOR same values -> zero
        check_outputs(4'h9, 4'h9, 3'b100, "DT-016");
        // DT-017: XOR complementary -> all ones
        check_outputs(4'h5, 4'hA, 3'b100, "DT-017");

        // ---- NOT operation ----
        // DT-018: NOT of zero -> all ones
        check_outputs(4'h0, 4'hX, 3'b101, "DT-018");
        // DT-019: NOT of all ones -> zero
        check_outputs(4'hF, 4'hX, 3'b101, "DT-019");
        // DT-020: NOT of mixed pattern
        check_outputs(4'hA, 4'hX, 3'b101, "DT-020");

        // ---- SHL operation ----
        // DT-021: SHL with MSB=1 -> carry=1, result shifts, MSB lost
        check_outputs(4'h8, 4'hX, 3'b110, "DT-021");
        // DT-022: SHL normal
        check_outputs(4'h3, 4'hX, 3'b110, "DT-022");
        // DT-023: SHL all ones -> carry=1, result=0xE
        check_outputs(4'hF, 4'hX, 3'b110, "DT-023");

        // ---- SHR operation ----
        // DT-024: SHR with LSB=1 -> carry=1, result shifts
        check_outputs(4'h1, 4'hX, 3'b111, "DT-024");
        // DT-025: SHR normal
        check_outputs(4'hA, 4'hX, 3'b111, "DT-025");
        // DT-026: SHR all ones -> carry=1, result=0x7
        check_outputs(4'hF, 4'hX, 3'b111, "DT-026");

        $display("Phase 1 complete: %0d passed, %0d failed", total_pass, total_fail);

        // ----------------------------------------------------------
        // PHASE 2 : RANDOMIZED TESTS
        //
        //   10,000 random {A, B, op} combinations.
        //   Each vector is compared to the golden model.
        //   A fixed seed makes results repeatable across runs.
        //   Change the seed to explore different stimulus sequences.
        // ----------------------------------------------------------

        $display("");
        $display("--- PHASE 2: RANDOMIZED TESTS (10,000 vectors, seed=42) ---");

        begin : random_phase
            // Declare loop variables at block level for compatibility
            int unsigned i;
            int unsigned rand_seed;
            logic [3:0]  rand_A;
            logic [3:0]  rand_B;
            logic [2:0]  rand_op;

            rand_seed = 42;

            for (i = 0; i < 10000; i++) begin
                // Simple LCG (Linear Congruential Generator)
                // for deterministic pseudo-random sequences.
                // srandom() is also valid in SV but LCG is more portable.
                rand_seed = rand_seed * 1664525 + 1013904223;
                rand_A    = rand_seed[3:0];

                rand_seed = rand_seed * 1664525 + 1013904223;
                rand_B    = rand_seed[3:0];

                rand_seed = rand_seed * 1664525 + 1013904223;
                rand_op   = rand_seed[2:0];

                check_outputs(rand_A, rand_B, rand_op, "RND");
            end
        end

        $display("Phase 2 complete: %0d total passed, %0d total failed",
                 total_pass, total_fail);

        // ----------------------------------------------------------
        // PHASE 3 : REPORTS
        // ----------------------------------------------------------
        print_coverage_report;
        print_final_summary;

        $finish;
    end

    // ============================================================
    // 10. SIMULATION TIMEOUT (safety net)
    //     Prevents a hung simulation from running forever.
    //     50 ms is far more than enough for combinational logic.
    // ============================================================
    initial begin
        #50_000_000;
        $display("[TIMEOUT] Simulation exceeded 50 ms - forcing stop.");
        $finish;
    end

endmodule