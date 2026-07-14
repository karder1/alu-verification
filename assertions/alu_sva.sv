// ============================================================
// File    : assertions/alu_sva.sv
// Project : 4-bit ALU Verification
// Author  : Bui Huu Phat
// Date    : 07/2026
//
// Description:
//   Immediate assertion checker for the combinational ALU.
//   All checks run from one process so assertion failures can be
//   counted reliably and included in the final regression result.
// ============================================================

`timescale 1ns / 1ps

module alu_sva (
    input  logic [3:0] A,
    input  logic [3:0] B,
    input  logic [2:0] op,
    input  logic [3:0] result,
    input  logic       carry,
    input  logic       zero,
    input  logic       overflow,
    output int unsigned assertion_fail_count
);

    initial assertion_fail_count = 0;

    // Use an explicit sensitivity list. assertion_fail_count is written
    // inside the block and must not become part of the sensitivity list.
    always @(A or B or op or result or carry or zero or overflow) begin
        #1; // Allow combinational DUT outputs to settle.

        // A1: zero is exactly equivalent to result == 0.
        assert_zero_flag:
            assert (zero == (result == 4'h0))
            else begin
                assertion_fail_count++;
                $error("[SVA FAIL] zero flag mismatch: result=%0h zero=%0b | op=%03b A=%0h B=%0h",
                       result, zero, op, A, B);
            end

        // A2: valid known inputs must never produce X/Z outputs.
        assert_no_x_result:
            assert (!$isunknown(result))
            else begin
                assertion_fail_count++;
                $error("[SVA FAIL] X/Z on result=%0b | op=%03b A=%0h B=%0h",
                       result, op, A, B);
            end

        assert_no_x_carry:
            assert (!$isunknown(carry))
            else begin
                assertion_fail_count++;
                $error("[SVA FAIL] X/Z on carry | op=%03b A=%0h B=%0h", op, A, B);
            end

        assert_no_x_zero:
            assert (!$isunknown(zero))
            else begin
                assertion_fail_count++;
                $error("[SVA FAIL] X/Z on zero | op=%03b A=%0h B=%0h", op, A, B);
            end

        assert_no_x_overflow:
            assert (!$isunknown(overflow))
            else begin
                assertion_fail_count++;
                $error("[SVA FAIL] X/Z on overflow | op=%03b A=%0h B=%0h", op, A, B);
            end

        // A3: logical operations do not generate carry or overflow.
        if (op inside {3'b010, 3'b011, 3'b100, 3'b101}) begin
            assert_logic_no_carry:
                assert (carry == 1'b0)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] carry=%0b for logical op=%03b | A=%0h B=%0h",
                           carry, op, A, B);
                end

            assert_logic_no_overflow:
                assert (overflow == 1'b0)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] overflow=%0b for logical op=%03b | A=%0h B=%0h",
                           overflow, op, A, B);
                end
        end

        // A4: every set bit in an AND result must exist in both operands.
        if (op == 3'b010) begin
            assert_and_subset_A:
                assert ((result & ~A) == 4'h0)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] AND result contains a bit absent from A | result=%0h A=%0h B=%0h",
                           result, A, B);
                end

            assert_and_subset_B:
                assert ((result & ~B) == 4'h0)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] AND result contains a bit absent from B | result=%0h A=%0h B=%0h",
                           result, A, B);
                end
        end

        // A5: every set bit in either operand must exist in an OR result.
        if (op == 3'b011) begin
            assert_or_superset_A:
                assert ((A & ~result) == 4'h0)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] OR result is missing a bit from A | result=%0h A=%0h B=%0h",
                           result, A, B);
                end

            assert_or_superset_B:
                assert ((B & ~result) == 4'h0)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] OR result is missing a bit from B | result=%0h A=%0h B=%0h",
                           result, A, B);
                end
        end

        // A6: XOR of equal operands must cancel to zero.
        if (op == 3'b100 && A == B) begin
            assert_xor_self_cancel:
                assert (result == 4'h0 && zero == 1'b1)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] XOR(A,A) must be zero | result=%0h A=%0h", result, A);
                end
        end

        // A7: SHL shifts out A[3] and shifts zero into result[0].
        if (op == 3'b110) begin
            assert_shl_carry:
                assert (carry == A[3])
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] SHL carry=%0b but A[3]=%0b | A=%0h",
                           carry, A[3], A);
                end

            assert_shl_lsb_zero:
                assert (result[0] == 1'b0)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] SHL result[0] must be zero | A=%0h result=%0h", A, result);
                end
        end

        // A8: SHR shifts out A[0] and shifts zero into result[3].
        if (op == 3'b111) begin
            assert_shr_carry:
                assert (carry == A[0])
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] SHR carry=%0b but A[0]=%0b | A=%0h",
                           carry, A[0], A);
                end

            assert_shr_msb_zero:
                assert (result[3] == 1'b0)
                else begin
                    assertion_fail_count++;
                    $error("[SVA FAIL] SHR result[3] must be zero | A=%0h result=%0h", A, result);
                end
        end
    end

endmodule
