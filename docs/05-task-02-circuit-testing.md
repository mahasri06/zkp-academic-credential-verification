# Task 02: ZKP Circuit Testing, Groth16 Setup, and Proof Verification

This document records the testing procedure, Groth16 setup, and verification results for the Academic Eligibility Circom circuit.

---

## 1. Overview and Scope

- **Objective:** Verify that the `academic_eligibility.circom` arithmetic circuit enforces all eligibility rules, correctly checks the Poseidon policy commitment, and binds proofs to a public session nonce.
- **Stage Type:** Proof-of-Concept (POC) local testing.
- **Scope Boundaries:**
  - Uses sample test inputs and parameters only.
  - No Spring Boot, MySQL, or real university database integration at this stage.
  - Digital signature verification of university credentials is deferred to subsequent stages.
  - Uses a local Powers of Tau ceremony ($2^{12}$) for testing purposes.

---

## 2. Circuit Refinement: Redundant Constraint Removal

In the previous iteration, `circuits/academic_eligibility.circom` contained an experimental quadratic constraint (`nonceSquare <== session_nonce * session_nonce;`) intended to prevent optimizer pruning.

Because `session_nonce` is already constrained by `Num2Bits(248)` (which decomposes the nonce into 248 boolean constraints with $b \cdot (1 - b) = 0$ and asserts their linear sum equals `session_nonce`), the signal is already fully constrained and cannot be optimized away.

**Change made:**
- Removed `signal nonceSquare;` and `nonceSquare <== session_nonce * session_nonce;` from `circuits/academic_eligibility.circom`.
- Preserved all other circuit signals, range checks, and matching constraints.

### Constraint and Signal Comparison:

| Metric | Before Refinement | After Refinement | Difference |
| :--- | :--- | :--- | :--- |
| **Total Constraints** | 1,300 | **1,299** | -1 (eliminated redundant multiplication) |
| **Non-linear Constraints** | 769 | **768** | -1 |
| **Linear Constraints** | 531 | **531** | 0 |
| **Wires** | 1,294 | **1,293** | -1 |
| **Labels** | 1,834 | **1,833** | -1 |
| **Public Inputs** | 2 | **2** | Unchanged |
| **Private Inputs** | 8 | **8** | Unchanged |

### Signal Ordering:
Inspecting `circuits/build/academic_eligibility.sym` confirms the public signal positions remain strictly preserved:
1. `Wire 1`: `main.policy_commitment` (Public Input #1)
2. `Wire 2`: `main.session_nonce` (Public Input #2)

---

## 3. Sample Test Values and Policy Commitment

### Test Parameters:
- `actual_cgpa`: `865` (representing 8.65)
- `actual_branch`: `101` (representing Computer Science)
- `actual_degree`: `1` (representing Bachelor of Technology / BE)
- `policy_id`: `1001`
- `min_cgpa`: `750` (representing minimum 7.50)
- `expected_branch`: `101`
- `expected_degree`: `1`
- `policy_version`: `1`
- `session_nonce`: `"123456789012345678901234567890"` (248-bit scalar field-safe integer)

### Poseidon Policy Commitment:
Using the official iden3 Poseidon reference implementation (`circomlibjs`), the 5-element input array:
```javascript
[1001, 750, 101, 1, 1]
```
produces the scalar field commitment:
```text
5897197218632289732648466379617052947848503139456971851739139381929576877198
```

---

## 4. Local Groth16 Trusted Setup Workflow

> [!WARNING]
> **Testing Only — Not for Production Use:**
> The Powers of Tau parameters ($2^{12}$) and circuit proving keys (`.zkey`) generated below were created locally on a single development machine with synthetic entropy purely for functional testing. They lack the cryptographic security guarantees of a multi-party computation (MPC) ceremony. For production deployment, a publicly audited multi-party trusted setup artifact (such as Hermez or Perpetual Powers of Tau) must be utilized.

Because the circuit contains 1,299 constraints, a Powers of Tau ceremony with $2^{12} = 4,096$ capacity was generated locally:

```powershell
# 1. Initialize local Powers of Tau (bn128, 2^12)
npx --prefix prover snarkjs powersOfTau new bn128 12 circuits/build/test_setup/pot12_0000.ptau -v

# 2. Add Phase 1 contribution
npx --prefix prover snarkjs powersOfTau contribute circuits/build/test_setup/pot12_0000.ptau circuits/build/test_setup/pot12_0001.ptau --name="Test" -v -e="academic_zkp_entropy_1"

# 3. Prepare Phase 2
npx --prefix prover snarkjs powersOfTau prepare phase2 circuits/build/test_setup/pot12_0001.ptau circuits/build/test_setup/pot12_final.ptau -v

# 4. Generate initial circuit proving key (.zkey)
npx --prefix prover snarkjs groth16 setup circuits/build/academic_eligibility.r1cs circuits/build/test_setup/pot12_final.ptau circuits/build/test_setup/circuit_0000.zkey

# 5. Add Phase 2 circuit-specific contribution
npx --prefix prover snarkjs zkey contribute circuits/build/test_setup/circuit_0000.zkey circuits/build/test_setup/circuit_final.zkey --name="Prover" -v -e="academic_zkp_entropy_2"

# 6. Export verification key
npx --prefix prover snarkjs zkey export verificationkey circuits/build/test_setup/circuit_final.zkey circuits/build/test_setup/verification_key.json
```

---

## 5. Valid Proof Generation and Verification

1. **Witness Generation:**
   The valid input values were processed using `circuits/build/academic_eligibility_js/witness_calculator.js`.
   - Output: `witness_valid.wtns` (41,452 bytes).
   - Result: Successful witness calculation without constraint violations.

2. **Groth16 Proof Generation:**
   ```powershell
   npx --prefix prover snarkjs groth16 prove circuits/build/test_setup/circuit_final.zkey circuits/build/test_setup/witness_valid.wtns circuits/build/test_setup/proof.json circuits/build/test_setup/public.json
   ```
   - Generated: `proof.json` (Groth16 $\pi_A, \pi_B, \pi_C$ elements on BN254) and `public.json`.

3. **Public Signals (`public.json`):**
   ```json
   [
     "5897197218632289732648466379617052947848503139456971851739139381929576877198",
     "123456789012345678901234567890"
   ]
   ```

4. **Verification:**
   ```powershell
   npx --prefix prover snarkjs groth16 verify circuits/build/test_setup/verification_key.json circuits/build/test_setup/public.json circuits/build/test_setup/proof.json
   ```
   - Output: `[INFO] snarkJS: OK!`
   - Exit code: `0` (Success).

---

## 6. Invalid Input Test Suite

Each test case evaluated a specific security rule in isolation against the circuit's WebAssembly witness calculator:

| Test Case | Tampered Input | Expected Result | Triggered Constraint in Circuit | Actual Witness Calculator Output | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Case 1: CGPA below minimum** | `actual_cgpa = 720`<br>`min_cgpa = 750` | Rejection (finite-field underflow) | Line 71: `deltaBits.in <== delta;` (`Num2Bits(10)`) | `Error: Assert Failed. Error in template Num2Bits_74 line: 38. Error in template AcademicEligibility_81 line: 71` | **PASSED** |
| **Case 2: Branch mismatch** | `actual_branch = 102`<br>`expected_branch = 101` | Rejection | Line 83: `actual_branch === expected_branch;` | `Error: Assert Failed. Error in template AcademicEligibility_81 line: 83` | **PASSED** |
| **Case 3: Degree mismatch** | `actual_degree = 2`<br>`expected_degree = 1` | Rejection | Line 92: `actual_degree === expected_degree;` | `Error: Assert Failed. Error in template AcademicEligibility_81 line: 92` | **PASSED** |
| **Case 4: CGPA above 1000** | `actual_cgpa = 1050`<br>(> 10.00 scale) | Rejection | Line 45: `actualCgpaBits.in <== actual_cgpa;` (`Num2Bits(10)`) | `Error: Assert Failed. Error in template Num2Bits_74 line: 38. Error in template AcademicEligibility_81 line: 45` | **PASSED** |
| **Case 5: Minimum CGPA above 1000** | `min_cgpa = 1050`<br>(> 10.00 scale) | Rejection | Line 54: `minCgpaBits.in <== min_cgpa;` (`Num2Bits(10)`) | `Error: Assert Failed. Error in template Num2Bits_74 line: 38. Error in template AcademicEligibility_81 line: 54` | **PASSED** |
| **Case 6: Incorrect policy commitment** | `policy_commitment = 999999...` | Rejection | Line 38: `policy_commitment === policyHasher.out;` | `Error: Assert Failed. Error in template AcademicEligibility_81 line: 38` | **PASSED** |

> [!NOTE]
> For values of `min_cgpa` between 1001 and 1023 (e.g., `1010`), `Num2Bits(10)` succeeds but the circuit fails at Line 59 (`minCgpaLimit.out === 1;`), correctly enforcing that the minimum CGPA never exceeds the 1000 ($10.00$) threshold under any condition.

All invalid cases were stopped at witness generation time, preventing invalid proofs from ever being synthesized.

---

## 7. Public Session Nonce Tampering Test

To confirm that the generated Groth16 proof is cryptographically bound to the public inputs:

1. Took the valid `proof.json` generated in Step 5.
2. Modified the second entry (`session_nonce`) in `public.json` from `"123456789012345678901234567890"` to `"999999999999999999999999999999"`.
3. Executed verification:
   ```powershell
   npx --prefix prover snarkjs groth16 verify circuits/build/test_setup/verification_key.json circuits/build/test_setup/public_tampered_nonce.json circuits/build/test_setup/proof.json
   ```
4. **Result:**
   - Output: `[ERROR] snarkJS: Invalid proof`
   - Exit code: `1` (Failure)

**Conclusion:** The pairing checks in the Groth16 verifier evaluate the public signals linear combination $IC_0 + \sum x_i IC_i$. Any modification to `session_nonce` or `policy_commitment` invalidates the pairing equation, preventing proof replay or frontrunning attacks across different sessions.

---

## 8. Limitations & Forward Roadmap

1. **Trusted Setup Parameters:**
   The current Powers of Tau file (`pot12_final.ptau`) and `.zkey` were generated locally with synthetic entropy for testing purposes. For production or formal staging, an established multi-party ceremony artifact (such as Hermez or Perpetual Powers of Tau) must be used.
2. **University Signature Checking:**
   The academic credentials (`actual_cgpa`, `actual_branch`, `actual_degree`) were supplied directly as private circuit inputs. Integration with university digital signatures (ECDSA/EdDSA or Ed25519) will be handled in subsequent stages to ensure private inputs originate from an authentic university authority.
3. **Backend Integration:**
   The Java backend will need to compute identical Poseidon hashes for employer policies and manage single-use session nonces for verification.
