pragma circom 2.0.0;

include "../prover/node_modules/circomlib/circuits/poseidon.circom";
include "../prover/node_modules/circomlib/circuits/bitify.circom";
include "../prover/node_modules/circomlib/circuits/comparators.circom";

template AcademicEligibility() {
    // =========================================================================
    // 1. PUBLIC SIGNALS (2) - Checked against employer/session context
    // =========================================================================
    signal input policy_commitment;
    signal input session_nonce;

    // =========================================================================
    // 2. PRIVATE SIGNALS (8) - Confidential credentials and policy details
    // =========================================================================
    signal input actual_cgpa;
    signal input actual_branch;
    signal input actual_degree;
    signal input policy_id;
    signal input min_cgpa;
    signal input expected_branch;
    signal input expected_degree;
    signal input policy_version;

    // =========================================================================
    // 3. POLICY COMMITMENT CONSTRAINTS (A)
    // =========================================================================
    // Authoritative policy commitment using standard Poseidon(5)
    component policyHasher = Poseidon(5);
    policyHasher.inputs[0] <== policy_id;
    policyHasher.inputs[1] <== min_cgpa;
    policyHasher.inputs[2] <== expected_branch;
    policyHasher.inputs[3] <== expected_degree;
    policyHasher.inputs[4] <== policy_version;

    // Assert computed commitment matches the expected public input
    policy_commitment === policyHasher.out;

    // =========================================================================
    // 4. CGPA RANGE CONSTRAINTS (B)
    // =========================================================================
    // actual_cgpa must be an integer in [0, 1000] (0.00 to 10.00 scaled by 100)
    component actualCgpaBits = Num2Bits(10);
    actualCgpaBits.in <== actual_cgpa;

    component actualCgpaLimit = LessEqThan(10);
    actualCgpaLimit.in[0] <== actual_cgpa;
    actualCgpaLimit.in[1] <== 1000;
    actualCgpaLimit.out === 1;

    // min_cgpa must be an integer in [0, 1000]
    component minCgpaBits = Num2Bits(10);
    minCgpaBits.in <== min_cgpa;

    component minCgpaLimit = LessEqThan(10);
    minCgpaLimit.in[0] <== min_cgpa;
    minCgpaLimit.in[1] <== 1000;
    minCgpaLimit.out === 1;

    // =========================================================================
    // 5. CGPA ELIGIBILITY CONSTRAINTS (C)
    // =========================================================================
    // delta = actual_cgpa - min_cgpa
    // If actual_cgpa < min_cgpa, subtraction underflows modulo r (~2^254),
    // which cannot be represented as a 10-bit integer.
    signal delta;
    delta <== actual_cgpa - min_cgpa;

    component deltaBits = Num2Bits(10);
    deltaBits.in <== delta;

    // =========================================================================
    // 6. BRANCH & DEGREE MATCHING CONSTRAINTS (D)
    // =========================================================================
    // Branch range check (32 bits) and exact equality matching
    component actualBranchBits = Num2Bits(32);
    actualBranchBits.in <== actual_branch;

    component expectedBranchBits = Num2Bits(32);
    expectedBranchBits.in <== expected_branch;

    actual_branch === expected_branch;

    // Degree range check (8 bits) and exact equality matching
    component actualDegreeBits = Num2Bits(8);
    actualDegreeBits.in <== actual_degree;

    component expectedDegreeBits = Num2Bits(8);
    expectedDegreeBits.in <== expected_degree;

    actual_degree === expected_degree;

    // =========================================================================
    // 7. POLICY VERSION CONSTRAINTS (E)
    // =========================================================================
    // policy_version must fit in 32 bits and be >= 1
    component policyVersionBits = Num2Bits(32);
    policyVersionBits.in <== policy_version;

    signal policyVersionOffset;
    policyVersionOffset <== policy_version - 1;

    component policyVersionOffsetBits = Num2Bits(32);
    policyVersionOffsetBits.in <== policyVersionOffset;

    // =========================================================================
    // 8. SESSION NONCE CONSTRAINTS (F)
    // =========================================================================
    // session_nonce must fit in 248 bits (strictly < r of BN254)
    component nonceBits = Num2Bits(248);
    nonceBits.in <== session_nonce;
}

// Instantiate main component with strictly ordered public signals
component main {public [policy_commitment, session_nonce]} = AcademicEligibility();
