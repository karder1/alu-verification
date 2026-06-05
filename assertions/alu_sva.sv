// ============================================================
// File    : assertions/alu_sva.sv
// Project : 4-bit ALU Verification
// Author  : Bui Huu Phat
// Date    : 06/2026
//
// Description:
//   Assertion checker module for alu.sv.
//   Uses immediate assertions inside always @(*) blocks because
//   the ALU is purely combinational.
//
//   Immediate assertions are evaluated like procedural code —
//   they fire exactly when the condition is false at that moment
//   in simulation time, with the #0 settle delay pattern.
//
//   HOW TO CONNECT:
//   This module is instantiated directly in the testbench.
//   In a real project you would use a SystemVerilog 'bind'
//   statement to attach it to the DUT without modifying RTL.
//   Both approaches are shown below.
// ============================================================

`timescale 1ns / 1ps

module alu_sva (
    // Mirror the DUT's port list exactly
    input logic [3:0] A,
    input logic [3:0] B,
    input logic [2:0] op,
    input logic [3:0] result,
    input logic       carry,
    input logic       zero,
    input logic       overflow
);

    // ============================================================
    // A1. ZERO FLAG CORRECTNESS
    //
    //   zero must be 1 if and only if result == 4'b0000.
    //   This is a universal invariant regardless of operation.
    // ============================================================
    always @(*) begin
        #1; // Small delay: let the DUT combinational logic settle
            // before we sample.  Without this, the assertion sees
            // intermediate glitches as the case statement updates.

        // assert (condition) else $error("message");
	assert_zero_flag : assert (zero == (result == 4'h0))
    		else $error("[SVA FAIL] zero flag mismatch: result=%0h zero=%0b | op=%03b A=%0h B=%0h",
                	result, zero, op, A, B);

    end

    // ============================================================
    // A2. NO X / Z ON ANY OUTPUT
    //
    //   Unknown (X) or high-impedance (Z) values on outputs indicate
    //   an incomplete case statement, undriven signal, or a latch.
    //   $isunknown() returns 1 if any bit is X or Z.
    // ============================================================
    always @(*) begin
        #1;
        assert_no_x_result : assert (!$isunknown(result))
            else $error("[SVA FAIL] assert_no_x_result: X/Z on result=%0b | op=%03b A=%0h B=%0h",
                        result, op, A, B);

        assert_no_x_carry : assert (!$isunknown(carry))
            else $error("[SVA FAIL] assert_no_x_carry: X/Z on carry | op=%03b A=%0h B=%0h",
                        op, A, B);

        assert_no_x_zero : assert (!$isunknown(zero))
            else $error("[SVA FAIL] assert_no_x_zero: X/Z on zero | op=%03b A=%0h B=%0h",
                        op, A, B);

        assert_no_x_overflow : assert (!$isunknown(overflow))
            else $error("[SVA FAIL] assert_no_x_overflow: X/Z on overflow | op=%03b A=%0h B=%0h",
                        op, A, B);
    end

    // ============================================================
    // A3. CARRY / OVERFLOW MUST BE 0 FOR LOGICAL OPERATIONS
    //
    //   AND, OR, XOR, NOT never produce a carry or overflow.
    //   If either flag is set for these opcodes, there is a bug.
    // ============================================================
    always @(*) begin
        #1;
        if (op inside {3'b010, 3'b011, 3'b100, 3'b101}) begin
            // Logical ops: carry and overflow must be 0
            assert_logic_no_carry : assert (carry == 1'b0)
                else $error("[SVA FAIL] assert_logic_no_carry: carry=%0b for logical op=%03b | A=%0h B=%0h",
                            carry, op, A, B);

            assert_logic_no_overflow : assert (overflow == 1'b0)
                else $error("[SVA FAIL] assert_logic_no_overflow: overflow=%0b for logical op=%03b | A=%0h B=%0h",
                            overflow, op, A, B);
        end
    end

    // ============================================================
    // A4. AND RESULT MUST BE A SUBSET OF BOTH OPERANDS
    //
    //   For AND: every bit in result must be set in both A and B.
    //   Formal property: (result & ~A) == 0 AND (result & ~B) == 0
    // ============================================================
    always @(*) begin
        #1;
        if (op == 3'b010) begin
            assert_and_subset_A : assert ((result & ~A) == 4'h0)
                else $error("[SVA FAIL] assert_and_subset_A: AND result has bit not in A | result=%0h A=%0h B=%0h",
                            result, A, B);

            assert_and_subset_B : assert ((result & ~B) == 4'h0)
                else $error("[SVA FAIL] assert_and_subset_B: AND result has bit not in B | result=%0h A=%0h B=%0h",
                            result, A, B);
        end
    end

    // ============================================================
    // A5. OR RESULT MUST BE A SUPERSET OF BOTH OPERANDS
    //
    //   For OR: every bit set in A or B must be set in result.
    //   Formal property: (A & ~result) == 0 AND (B & ~result) == 0
    // ============================================================
    always @(*) begin
        #1;
        if (op == 3'b011) begin
            assert_or_superset_A : assert ((A & ~result) == 4'h0)
                else $error("[SVA FAIL] assert_or_superset_A: OR result missing bit from A | result=%0h A=%0h B=%0h",
                            result, A, B);

            assert_or_superset_B : assert ((B & ~result) == 4'h0)
                else $error("[SVA FAIL] assert_or_superset_B: OR result missing bit from B | result=%0h A=%0h B=%0h",
                            result, A, B);
        end
    end

    // ============================================================
    // A6. XOR SELF-CANCEL: XOR(A, A) == 0
    //
    //   When both operands are equal, XOR must produce zero.
    // ============================================================
    always @(*) begin
        #1;
        if (op == 3'b100 && A == B) begin
            assert_xor_self_cancel : assert (result == 4'h0 && zero == 1'b1)
                else $error("[SVA FAIL] assert_xor_self_cancel: XOR(A,A) should be 0 | result=%0h A=%0h",
                            result, A);
        end
    end

    // ============================================================
    // A7. SHL CARRY EQUALS ORIGINAL MSB
    //
    //   After SHL, carry should equal what A[3] was before the shift.
    //   result[0] must always be 0 (a zero is shifted in).
    // ============================================================
    always @(*) begin
        #1;
        if (op == 3'b110) begin
            assert_shl_carry : assert (carry == A[3])
                else $error("[SVA FAIL] assert_shl_carry: SHL carry=%0b but A[3]=%0b | A=%0h",
                            carry, A[3], A);

            assert_shl_lsb_zero : assert (result[0] == 1'b0)
                else $error("[SVA FAIL] assert_shl_lsb_zero: SHL result[0]=%0b should be 0 | A=%0h result=%0h",
                            result[0], A, result);
        end
    end

    // ============================================================
    // A8. SHR CARRY EQUALS ORIGINAL LSB
    //
    //   After SHR, carry should equal what A[0] was before the shift.
    //   result[3] must always be 0 (a zero is shifted in).
    // ============================================================
    always @(*) begin
        #1;
        if (op == 3'b111) begin
            assert_shr_carry : assert (carry == A[0])
                else $error("[SVA FAIL] assert_shr_carry: SHR carry=%0b but A[0]=%0b | A=%0h",
                            carry, A[0], A);

            assert_shr_msb_zero : assert (result[3] == 1'b0)
                else $error("[SVA FAIL] assert_shr_msb_zero: SHR result[3]=%0b should be 0 | A=%0h result=%0h",
                            result[3], A, result);
        end
    end

endmodule