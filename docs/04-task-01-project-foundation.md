# Task 01: Project Foundation and Environment Setup

## 1. Task Overview

Task 01 establishes the foundational project structure, security boundaries, and local development environment for the **Policy-Driven Zero-Knowledge Academic Credential Verification System**.

The primary objective was to ensure that all necessary tools and compilers are properly installed, verified, and configured before starting any circuit design or backend implementation.

---

## 2. Why We Did This

Zero-Knowledge Proof (ZKP) projects combine cryptographic compilers, client-side proof generation engines, and backend enterprise services. Setting up a solid foundation first is critical:

1. **Preventing Broken Workflows:** 
   Circuit compilers (`circom`) and proving libraries (`snarkjs`) must be compatible. Verifying exact versions upfront avoids unexpected errors during circuit compilation and proof generation.
2. **Preventing Leaks and Repository Clutter:** 
   ZKP workflows generate large binary files (keys, constraint files, intermediate data). Having a clean `.gitignore` in place from day one ensures that private credentials, local witness files, and massive temporary keys are never accidentally committed to Git.
3. **Establishing Clear System Boundaries:** 
   Knowing exactly what runs on the student's personal computer versus what runs on the employer's server ensures the system remains truly privacy-preserving.

---

## 3. Directory Structure

We organized the repository into clean, independent modules:

```text
Academic-ZKP-Verification/
├── backend/        # Spring Boot backend (Policy definition, nonce generation, proof verification)
├── circuits/       # Circom arithmetic circuits (Eligibility rules and constraints)
├── prover/         # Client-side Node.js environment (Local witness computation & proof generation)
├── docs/           # Documentation, architectural decisions, and interview revision guides
├── experiments/    # Performance benchmarks and measurement scripts
├── .gitignore      # Ignores build artifacts, temporary files, and private inputs
└── README.md       # High-level architecture and project overview
```

---

## 4. Implementation Status of System Components

To maintain technical accuracy, the project components are categorized by their current implementation state:

### Implemented and Verified
- **Workspace Structure:** Clean, decoupled directory layout.
- **Repository Hygiene:** Comprehensive root `.gitignore`.
- **Java Environment:** Eclipse Temurin OpenJDK 21 LTS configured in `JAVA_HOME`.
- **Build Tooling:** Apache Maven 3.9.16 running successfully on Java 21 LTS.
- **Client Runtime:** Node.js v22.7.0 and npm 10.8.2 verified.
- **ZK Compiler:** Circom 2.2.3 standalone binary installed and added to User PATH.
- **ZKP Library:** snarkjs 0.7.6 installed locally in `prover/package.json` with a locked `package-lock.json`.
- **Database Engine:** MySQL Server 8.0.34 installed with the `MySQL80` service active.

### Planned for Future Implementation
- **Eligibility Circuits:** `.circom` circuits enforcing grade scaling, range checks, and branch/degree matching.
- **Student CLI Prover:** Client scripts to load local credential files, compute witness data, and generate proofs.
- **Backend Service:** Spring Boot 3.x REST controllers for managing policies and verifying incoming proofs.
- **Database Schema:** MySQL tables for policies, active session challenges, and verification receipts.
- **Replay Protection System:** Server-side challenge nonce lifecycle management to prevent replaying valid proofs.

### Under Active Investigation
- **Issuer Digital Signatures:** Investigating in-circuit signature verification (such as EdDSA over the BabyJubjub curve) so circuits can cryptographically prove that credentials were authentic and unmodified by the student.

---

## 5. Verified Tools and Technologies

| Tool / Technology | Version Verified | Architectural Role |
| :--- | :--- | :--- |
| **Circom** | `2.2.3` | **Circuit Compiler:** Compiles eligibility rules written in Circom into arithmetic constraint systems and witness calculators. |
| **snarkjs** | `0.7.6` | **ZKP Engine:** Generates proving/verification keys, calculates client-side Groth16 proofs, and verifies proofs. |
| **BN254 (alt_bn128)** | Standard Curve | **Elliptic Curve:** The pairing-friendly curve used by Groth16 zk-SNARKs. |
| **Eclipse Temurin JDK** | `21.0.13 LTS` | **Backend Runtime:** Modern LTS Java virtual machine used for the verification backend. |
| **Apache Maven** | `3.9.16` | **Build Tool:** Manages dependencies and packaging for the backend service. |
| **Node.js & npm** | `v22.7.0` / `10.8.2` | **Client Runtime:** Runs client-side CLI scripts for witness computation and local proof generation. |
| **MySQL Server** | `8.0.34` | **Database:** Stores policies, single-use session nonces, and audit logs. |

---

## 6. High-Level Project Architecture

The system uses a decoupled, three-party verification model:

```text
[ University (Issuer) ]
         |
         | (Issues signed academic credential - Planned)
         v
[ Student Local Machine (Holder / Prover) ]
   - Holds private credential file (Exact CGPA, Branch, Degree)
   - Runs Circom eligibility circuit locally
   - Computes witness and generates Groth16 proof (π) locally
         |
         | (Transmits ONLY the proof π and required public inputs)
         v
[ Employer / Verification Backend (Verifier) ]
   - Defines eligibility policy (e.g., Minimum CGPA: 7.50)
   - Issues single-use session challenge nonces
   - Verifies the proof mathematically without seeing the transcript
   - Stores audit records in MySQL
```

### Core Privacy Rule
- **Kept Local to Student:** The student's actual grades, raw transcripts, course history, personal identifiers, and private witness data never leave the student's device.
- **Transmitted to Verifier:** Only the zero-knowledge proof ($\pi$) and declared public requirements (minimum CGPA threshold, required degree, session challenge nonce).

---

## 7. Problems and Solutions Encountered

### 1. Windows PATH Priority (Oracle Java 23 vs. Temurin Java 21)
- **Problem:** `JAVA_HOME` pointed to Java 21, but typing `java -version` in PowerShell launched Oracle Java 23.
- **Cause:** Windows evaluates Machine PATH before User PATH. Oracle registered its `javapath` shortcut at the very beginning of Machine PATH.
- **Solution:**
  - We verified that Apache Maven (`mvn.cmd`) explicitly targets `%JAVA_HOME%\bin\java.exe`, ensuring all backend compilation runs on Java 21 LTS as required.
  - Modifying Machine PATH requires Administrator privileges. Following safe development practices, we avoided unsafe hacks or registry overrides and documented the standard admin command for reordering PATH if desired.

### 2. Missing Circom Compiler
- **Problem:** `circom` was not installed on the system.
- **Cause:** Circom does not come with standard package managers on Windows.
- **Solution:** Downloaded the official, standalone `circom-windows-amd64.exe` (v2.2.3) from the official iden3 release repository, saved it as `C:\Users\admin\Tools\circom\circom.exe`, and added the directory to User PATH.

### 3. Missing snarkjs Library
- **Problem:** `snarkjs` was not available for generating or verifying proofs.
- **Solution:** Initialized `package.json` in `prover/` and installed `snarkjs@0.7.6` as a local project dependency. This guarantees reproducible builds locked via `package-lock.json` and avoids polluting global npm packages.

### 4. Git Ignore Rules for Public vs. Private Artifacts
- **Problem:** Blindly ignoring all ZKP files could accidentally ignore public verification keys that the backend application needs.
- **Solution:** Structured `.gitignore` to distinguish between private/large intermediate files (`*.wtns`, `*.ptau`, `*.zkey`, temporary proofs) while keeping application code and intentional public configuration clean.

---

## 8. Core Concepts to Understand

- **Zero-Knowledge Proof (ZKP):** A cryptographic method where Alice can prove to Bob that a statement is true (e.g., *"My CGPA is at least 7.50"*) without revealing the underlying secret (her actual CGPA).
- **Groth16 zk-SNARK:** A popular zero-knowledge proving system known for generating very small proofs and enabling fast, constant-time verification on backend servers.
- **Fixed-Point Scaling ($\times 100$):** ZKP arithmetic circuits cannot work with decimal numbers directly. To handle decimal grades like `8.65`, we scale them by multiplying by $100$ (e.g., `8.65` becomes integer `865`, and `7.50` becomes `750`).
- **Session Challenge Nonce:** A random, single-use token issued by the verifier for a specific session. Binding this token into the proof prevents replay attacks, where an attacker intercepts a valid proof and attempts to reuse it.
- **Data Minimization:** A privacy principle stating that organizations should only collect the minimum personal data strictly necessary to make a decision. ZKPs enable verification while achieving complete data minimization.

---

## 9. Beginner-Level Interview Questions and Answers

### Q1: What real-world problem does this project address?
**Answer:** In traditional job applications, candidates must share complete, unredacted transcripts to prove basic qualifications (like having a CGPA above 7.50). This unnecessarily exposes sensitive information like semester-by-semester grades, backlogs, and personal identifiers. This project allows candidates to mathematically prove their eligibility using Zero-Knowledge Proofs without sharing their actual transcripts.

### Q2: What are the three roles in your architecture, and what do they do?
**Answer:**
1. **Issuer (University):** Issues genuine academic credentials to students.
2. **Holder / Prover (Student):** Stores credentials locally on their computer and generates a zero-knowledge proof using a local circuit runner.
3. **Verifier (Employer):** Sets eligibility policies, issues session nonces, and mathematically verifies incoming proofs on a Spring Boot backend.

### Q3: What is the difference between a private witness and a public signal?
**Answer:** 
- A **private witness** is confidential data that stays entirely on the student's machine (e.g., actual CGPA, degree, private witness calculations).
- A **public signal** is shared with the verifier so they can verify the proof against their requirements (e.g., minimum CGPA threshold, session challenge nonce).

### Q4: Why is proof generation performed on the student's computer instead of the employer's server?
**Answer:** If the student sent their grades to the employer's server to generate the proof, the employer would already have seen the private data, defeating the entire purpose of zero-knowledge privacy. Generating the proof locally ensures private data never leaves the student's device.

### Q5: Why do we multiply CGPA values by 100 in this project?
**Answer:** Zero-knowledge circuits work only with integers and whole numbers. To avoid floating-point inaccuracies, we scale decimal grades by multiplying by 100 (converting `8.65` to `865`), allowing the circuit to perform standard integer comparisons.

### Q6: What is a session nonce and why is it needed?
**Answer:** A zero-knowledge proof by itself could theoretically be intercepted and re-submitted by someone else. A session nonce is a unique, one-time number generated by the backend verifier. The student binds this nonce into their proof, ensuring the proof is valid only for that specific session and cannot be replayed.

### Q7: Why did you install snarkjs locally in `prover/` instead of globally?
**Answer:** Installing `snarkjs` locally in `prover/package.json` ensures that anyone cloning the project gets the exact same version (`0.7.6`) via `package-lock.json`. It prevents version conflicts and ensures reproducible builds across different development machines.
