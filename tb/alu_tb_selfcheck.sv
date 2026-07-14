// ============================================================
// File    : tb/alu_tb_selfcheck.sv
// Project : 4-bit ALU Verification
// Author  : Bui Huu Phat
// Date    : 07/2026
//
// Description:
//   Self-checking testbench for alu.sv.
//
//   Verification flow:
//     Phase 1 - 26 directed corner-case tests
//     Phase 2 - exhaustive testing of all 2,048 valid inputs
//     Phase 3 - scoreboard, assertion and coverage summary
// ============================================================

`timescale 1ns / 1ps

module alu_tb_selfcheck;

    // DUT interface
    logic [3:0] A;
    logic [3:0] B;
    logic [2:0] op;
    logic [3:0] result;
    logic       carry;
    logic       zero;
    logic       overflow;

    alu dut (
        .A        (A),
        .B        (B),
        .op       (op),
        .result   (result),
        .carry    (carry),
        .zero     (zero),
        .overflow (overflow)
    );

    // Assertion failures are reported separately from scoreboard mismatches.
    int unsigned assertion_fail_count;

    alu_sva u_sva (
        .A                    (A),
        .B                    (B),
        .op                   (op),
        .result               (result),
        .carry                (carry),
        .zero                 (zero),
        .overflow             (overflow),
        .assertion_fail_count (assertion_fail_count)
    );

    // Scoreboard counters
    int unsigned total_tests = 0;
    int unsigned total_pass  = 0;
    int unsigned total_fail  = 0;

    // Manual functional coverage targets: 8 + 3 + 5 = 16 targets.
    logic [7:0] op_seen = 8'h00;

    logic cov_carry_high    = 1'b0;
    logic cov_zero_high     = 1'b0;
    logic cov_overflow_high = 1'b0;

    logic cov_A_zero = 1'b0;
    logic cov_A_ones = 1'b0;
    logic cov_B_zero = 1'b0;
    logic cov_B_ones = 1'b0;
    logic cov_A_eq_B = 1'b0;

    // ============================================================
    // Independent reference model
    //
    // The RTL detects overflow with sign-bit Boolean equations.
    // This model instead sign-extends the operands and checks whether
    // the mathematical result lies outside the 4-bit signed range
    // [-8, +7]. SUB borrow is computed directly with A < B.
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
        logic        [4:0] unsigned_calc;
        logic signed [4:0] signed_A;
        logic signed [4:0] signed_B;
        logic signed [5:0] signed_calc;
        begin
            exp_result   = 4'h0;
            exp_carry    = 1'b0;
            exp_overflow = 1'b0;
            unsigned_calc = 5'h00;
            signed_A      = {gA[3], gA};
            signed_B      = {gB[3], gB};
            signed_calc   = 6'sd0;

            case (gop)
                3'b000: begin // ADD
                    unsigned_calc = {1'b0, gA} + {1'b0, gB};
                    signed_calc   = signed_A + signed_B;
                    exp_result    = unsigned_calc[3:0];
                    exp_carry     = (unsigned_calc > 5'd15);
                    exp_overflow  = (signed_calc > 6'sd7) ||
                                    (signed_calc < -6'sd8);
                end

                3'b001: begin // SUB
                    signed_calc  = signed_A - signed_B;
                    exp_result   = gA - gB;
                    exp_carry    = (gA < gB); // carry output is the borrow flag
                    exp_overflow = (signed_calc > 6'sd7) ||
                                   (signed_calc < -6'sd8);
                end

                3'b010: exp_result = gA & gB;
                3'b011: exp_result = gA | gB;
                3'b100: exp_result = gA ^ gB;
                3'b101: exp_result = ~gA;

                3'b110: begin
                    exp_result = gA << 1;
                    exp_carry  = gA[3];
                end

                3'b111: begin
                    exp_result = gA >> 1;
                    exp_carry  = gA[0];
                end

                default: exp_result = 4'h0;
            endcase

            exp_zero = (exp_result == 4'h0);
        end
    endtask

    // Apply one vector, calculate the expected outputs and compare them.
    task automatic check_outputs (
        input logic [3:0] in_A,
        input logic [3:0] in_B,
        input logic [2:0] in_op,
        input string      test_label,
        input bit         print_on_pass
    );
        logic [3:0] exp_r;
        logic       exp_c;
        logic       exp_z;
        logic       exp_ov;
        begin
            A  = in_A;
            B  = in_B;
            op = in_op;
            #10;

            golden_model(in_A, in_B, in_op, exp_r, exp_c, exp_z, exp_ov);
            total_tests++;

            // Sample functional coverage after the DUT has settled.
            op_seen[in_op] = 1'b1;
            if (carry)              cov_carry_high    = 1'b1;
            if (zero)               cov_zero_high     = 1'b1;
            if (overflow)           cov_overflow_high = 1'b1;
            if (in_A == 4'h0)       cov_A_zero        = 1'b1;
            if (in_A == 4'hF)       cov_A_ones        = 1'b1;
            if (in_B == 4'h0)       cov_B_zero        = 1'b1;
            if (in_B == 4'hF)       cov_B_ones        = 1'b1;
            if (in_A === in_B)      cov_A_eq_B        = 1'b1;

            if (result   !== exp_r  ||
                carry    !== exp_c  ||
                zero     !== exp_z  ||
                overflow !== exp_ov) begin

                $display("[FAIL] %-8s | op=%03b A=%0h B=%0h | DUT: res=%0h c=%0b z=%0b ov=%0b | EXP: res=%0h c=%0b z=%0b ov=%0b",
                         test_label, in_op, in_A, in_B,
                         result, carry, zero, overflow,
                         exp_r, exp_c, exp_z, exp_ov);
                total_fail++;
            end
            else begin
                if (print_on_pass)
                    $display("[PASS] %-8s | op=%03b A=%0h B=%0h -> result=%0h carry=%0b zero=%0b overflow=%0b",
                             test_label, in_op, in_A, in_B,
                             result, carry, zero, overflow);
                total_pass++;
            end
        end
    endtask

    function automatic bit coverage_complete;
        begin
            coverage_complete = (&op_seen)          &&
                                cov_carry_high       &&
                                cov_zero_high        &&
                                cov_overflow_high    &&
                                cov_A_zero           &&
                                cov_A_ones           &&
                                cov_B_zero           &&
                                cov_B_ones           &&
                                cov_A_eq_B;
        end
    endfunction

    function automatic bit verification_passed;
        begin
            verification_passed = (total_fail == 0) &&
                                  (assertion_fail_count == 0) &&
                                  coverage_complete();
        end
    endfunction

    task automatic print_coverage_report;
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
            $display("----------------------------------------------");
            $display("Coverage closure  : %s", coverage_complete() ? "PASS" : "FAIL");
            $display("==============================================");
        end
    endtask

    task automatic print_final_summary;
        begin
            $display("");
            $display("==============================================");
            $display("            SIMULATION SUMMARY               ");
            $display("==============================================");
            $display("Total vectors       : %0d", total_tests);
            $display("Scoreboard passed   : %0d", total_pass);
            $display("Scoreboard failed   : %0d", total_fail);
            $display("Assertion failures  : %0d", assertion_fail_count);
            $display("Coverage closure    : %s", coverage_complete() ? "PASS" : "FAIL");
            $display("----------------------------------------------");
            if (verification_passed())
                $display(">>> ALL VERIFICATION CHECKS PASSED <<<");
            else
                $display(">>> VERIFICATION FAILED - CHECK LOG ABOVE <<<");
            $display("==============================================");
        end
    endtask

    initial begin : main_stimulus
        int unsigned a_value;
        int unsigned b_value;
        int unsigned op_value;
        int unsigned directed_pass_before;
        int unsigned directed_fail_before;

        A  = 4'h0;
        B  = 4'h0;
        op = 3'b000;
        #5;

        $display("");
        $display("==============================================");
        $display("   ALU SELF-CHECKING TESTBENCH - START       ");
        $display("==============================================");
        $display("");
        $display("--- PHASE 1: DIRECTED TESTS ---");

        directed_pass_before = total_pass;
        directed_fail_before = total_fail;

        // ADD
        check_outputs(4'h3, 4'h5, 3'b000, "DT-001", 1'b1);
        check_outputs(4'hF, 4'h1, 3'b000, "DT-002", 1'b1);
        check_outputs(4'h7, 4'h1, 3'b000, "DT-003", 1'b1);
        check_outputs(4'h0, 4'h5, 3'b000, "DT-004", 1'b1);
        check_outputs(4'h0, 4'h0, 3'b000, "DT-005", 1'b1);
        // 0xF + 0xF = 0x1E -> result=E, carry=1, zero=0.
        check_outputs(4'hF, 4'hF, 3'b000, "DT-006", 1'b1);

        // SUB
        // Use 7 - 3 as a basic non-overflow subtraction.
        check_outputs(4'h7, 4'h3, 3'b001, "DT-007", 1'b1);
        check_outputs(4'h0, 4'h1, 3'b001, "DT-008", 1'b1);
        check_outputs(4'h5, 4'h5, 3'b001, "DT-009", 1'b1);
        check_outputs(4'h8, 4'h1, 3'b001, "DT-010", 1'b1);

        // AND
        check_outputs(4'h5, 4'hA, 3'b010, "DT-011", 1'b1);
        check_outputs(4'h7, 4'hF, 3'b010, "DT-012", 1'b1);
        check_outputs(4'hF, 4'h0, 3'b010, "DT-013", 1'b1);

        // OR
        check_outputs(4'h5, 4'hA, 3'b011, "DT-014", 1'b1);
        check_outputs(4'h7, 4'h0, 3'b011, "DT-015", 1'b1);

        // XOR
        check_outputs(4'h9, 4'h9, 3'b100, "DT-016", 1'b1);
        check_outputs(4'h5, 4'hA, 3'b100, "DT-017", 1'b1);

        // NOT: B is deliberately X because this operation must ignore B.
        check_outputs(4'h0, 4'hX, 3'b101, "DT-018", 1'b1);
        check_outputs(4'hF, 4'hX, 3'b101, "DT-019", 1'b1);
        check_outputs(4'hA, 4'hX, 3'b101, "DT-020", 1'b1);

        // SHL: B is deliberately X because this operation must ignore B.
        check_outputs(4'h8, 4'hX, 3'b110, "DT-021", 1'b1);
        check_outputs(4'h3, 4'hX, 3'b110, "DT-022", 1'b1);
        check_outputs(4'hF, 4'hX, 3'b110, "DT-023", 1'b1);

        // SHR: B is deliberately X because this operation must ignore B.
        check_outputs(4'h1, 4'hX, 3'b111, "DT-024", 1'b1);
        check_outputs(4'hA, 4'hX, 3'b111, "DT-025", 1'b1);
        check_outputs(4'hF, 4'hX, 3'b111, "DT-026", 1'b1);

        $display("Phase 1 complete: %0d passed, %0d failed",
                 total_pass - directed_pass_before,
                 total_fail - directed_fail_before);

        // The complete valid input space is small:
        // 16 values of A x 16 values of B x 8 opcodes = 2,048 vectors.
        $display("");
        $display("--- PHASE 2: EXHAUSTIVE TESTS (2,048 vectors) ---");

        for (op_value = 0; op_value < 8; op_value++) begin
            for (a_value = 0; a_value < 16; a_value++) begin
                for (b_value = 0; b_value < 16; b_value++) begin
                    check_outputs(a_value, b_value, op_value, "EXH", 1'b0);
                end
            end
        end

        $display("Phase 2 complete: %0d total passed, %0d total failed",
                 total_pass, total_fail);

        print_coverage_report;
        print_final_summary;

        if (verification_passed())
            $finish;
        else
            $fatal(1, "ALU verification failed.");
    end

    // Safety net. The exhaustive simulation should finish around 21 us.
    initial begin : timeout_watchdog
        #1_000_000; // 1 ms
        $fatal(1, "[TIMEOUT] Simulation exceeded 1 ms.");
    end

endmodule
