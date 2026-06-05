// ============================================================
// File    : rtl/alu.sv
// Project : 4-bit ALU Verification
// Author  : Bui Huu Phat
// Date    : 06/2026
//
// Description:
//   4-bit Arithmetic Logic Unit (ALU) — the Design Under Test (DUT).
//   Supports 8 operations selected by a 3-bit opcode.
//   Produces a 4-bit result plus three status flags:
//     carry    — unsigned carry-out (ADD/SHR/SHL) or borrow (SUB)
//     zero     — asserted when result == 0
//     overflow — signed two's-complement overflow (ADD/SUB only)
//
// Operation Table:
//   op[2:0] | Mnemonic | Operation
//   --------+----------+------------------
//   3'b000  | ADD      | result = A + B
//   3'b001  | SUB      | result = A - B
//   3'b010  | AND      | result = A & B
//   3'b011  | OR       | result = A | B
//   3'b100  | XOR      | result = A ^ B
//   3'b101  | NOT      | result = ~A  (B ignored)
//   3'b110  | SHL      | result = A << 1, carry = A[3]
//   3'b111  | SHR      | result = A >> 1, carry = A[0]
// ============================================================

`timescale 1ns / 1ps

module alu (
    input  logic [3:0] A,        // Operand A
    input  logic [3:0] B,        // Operand B  (not used by NOT, SHL, SHR)
    input  logic [2:0] op,       // Operation select
    output logic [3:0] result,   // 4-bit computation result
    output logic       carry,    // Carry / borrow / shift-out flag
    output logic       zero,     // High when result == 4'b0000
    output logic       overflow  // Signed overflow (ADD/SUB only)
);

    // ----------------------------------------------------------------
    // 5-bit intermediate wire captures the full carry/borrow bit
    // from addition and subtraction without truncation.
    // Bit [4] is the carry-out; bits [3:0] are the real result.
    // ----------------------------------------------------------------
    logic [4:0] full_result;

    // ----------------------------------------------------------------
    // Combinational ALU logic.
    // 'always_comb' (SystemVerilog) is preferred over 'always @(*)'
    // because the simulator will warn you if the block has latches.
    // ----------------------------------------------------------------
    always_comb begin

        // --- Safe defaults -------------------------------------------
        // Setting defaults prevents unintentional latches.
        // Every signal MUST be driven on every path through the case.
        result      = 4'b0000;
        carry       = 1'b0;
        overflow    = 1'b0;
        full_result = 5'b00000;

        case (op)

            // ----------------------------------------------------------
            // ADD : unsigned addition with carry out
            //       Signed overflow detection:
            //         pos + pos = neg  →  overflow
            //         neg + neg = pos  →  overflow
            // ----------------------------------------------------------
            3'b000: begin
                full_result = {1'b0, A} + {1'b0, B};   // 5-bit addition
                result      = full_result[3:0];
                carry       = full_result[4];            // unsigned carry out
                overflow    = (~A[3] & ~B[3] &  result[3])   
                            | ( A[3] &  B[3] & ~result[3]);  
            end

            // ----------------------------------------------------------
            // SUB : unsigned subtraction with borrow
            //       Borrow is full_result[4] (high when A < B).
            //       Signed overflow:
            //         pos - neg = neg  →  overflow
            //         neg - pos = pos  →  overflow
            // ----------------------------------------------------------
            3'b001: begin
                full_result = {1'b0, A} - {1'b0, B};
                result      = full_result[3:0];
                carry       = full_result[4];            // borrow flag
                overflow    = (~A[3] &  B[3] &  result[3])   
                            | ( A[3] & ~B[3] & ~result[3]);  
            end

            // ----------------------------------------------------------
            // AND / OR / XOR : bitwise logical — no flags
            // ----------------------------------------------------------
            3'b010: result = A & B;
            3'b011: result = A | B;
            3'b100: result = A ^ B;

            // ----------------------------------------------------------
            // NOT : bitwise invert of A only (B is ignored)
            // ----------------------------------------------------------
            3'b101: result = ~A;

            // ----------------------------------------------------------
            // SHL : logical shift left by 1
            //       The MSB that is shifted out becomes carry.
            //       A zero is shifted into the LSB.
            // ----------------------------------------------------------
            3'b110: begin
                result = A << 1;     // A[0] becomes 0; A[3] is lost
                carry  = A[3];       // MSB shifted out
            end

            // ----------------------------------------------------------
            // SHR : logical shift right by 1
            //       The LSB that is shifted out becomes carry.
            //       A zero is shifted into the MSB.
            // ----------------------------------------------------------
            3'b111: begin
                result = A >> 1;     // A[3] becomes 0; A[0] is lost
                carry  = A[0];       // LSB shifted out
            end

            // Default covers unused 3-bit codes (none here, but good practice)
            default: result = 4'b0000;

        endcase

        // ---------------------------------------------------------------
        // Zero flag: combinational, derived from final result.
        // Written outside the case so it applies to ALL operations.
        // ---------------------------------------------------------------
        zero = (result == 4'b0000);

    end

endmodule