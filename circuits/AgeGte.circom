pragma circom 2.1.6;

// ============================================================================
// Veritas — "AgeGte": range proof that age >= threshold (e.g. 18), derived
// from a date of birth WITHOUT revealing the DOB.
// ============================================================================
// MVP primitive #1 from the build brief.
//
// The prover supplies their private date of birth (dob_day, dob_month,
// dob_year) and a blinding salt. The verifier supplies a reference "now"
// date and the threshold (both PUBLIC — the verifier controls them so the
// prover cannot move the clock). The circuit computes the holder's age from
// the DOB and proves `age >= threshold`.
//
// HOW AGE IS COMPUTED FROM DOB
//   age_full   = now_year - dob_year
//   notHadBday = 1 if (now_month < dob_month)
//                    OR (now_month == dob_month AND now_day < dob_day), else 0
//   age        = age_full - notHadBday
//
// SECURITY NOTES
//   * `age >= threshold`  <=>  NOT(age < threshold). We assert
//     `LessThan(16)(age, threshold) === 0`. circomlib's LessThan(n) internally
//     decomposes `age + 2^n - threshold` with Num2Bits(n+1), which IMPLICITLY
//     forces that value into [0, 2^(n+1)). A wrapped/negative `age` (e.g. a
//     future DOB) is therefore UNSATISFIABLE — no Groth16 proof can ever be
//     forged for an underage holder. 16 bits covers any plausible human age.
//   * DOB stays private; only an opaque Poseidon commitment is exposed, so the
//     proof is non-malleable and bound to a specific credential.
//
// Primitives: circomlib `LessThan` + `IsEqual` (comparators.circom),
//             circomlib `Poseidon` (poseidon.circom).
// Proof system: Groth16 on BN254 (verified on-chain by a Soroban contract).
// ============================================================================

include "node_modules/circomlib/circuits/comparators.circom";
include "node_modules/circomlib/circuits/poseidon.circom";

template AgeGte() {
    // ---- private inputs (the credential) ----
    signal input dob_year;   // e.g. 2003
    signal input dob_month;  // 1..12
    signal input dob_day;    // 1..31
    signal input salt;       // blinding salt for the commitment

    // ---- public inputs (verifier-controlled) ----
    signal input now_year;   // reference year, e.g. 2026
    signal input now_month;  // 1..12
    signal input now_day;    // 1..31
    signal input threshold;  // required minimum age (e.g. 18)

    // ---- public outputs ----
    signal output commitment; // Poseidon(dob_year, dob_month, dob_day, salt)
    signal output ageGte;     // 1 for any valid proof (circuit is unsatisfiable otherwise)

    // --- date validity (lightweight: 5 bits => < 32; covers day/month) ---
    component dayOk   = LessThan(5); dayOk.in[0]   <== dob_day;   dayOk.in[1]   <== 32; dayOk.out   === 1;
    component monthOk = LessThan(5); monthOk.in[0] <== dob_month; monthOk.in[1] <== 13; monthOk.out === 1;
    component ndayOk  = LessThan(5); ndayOk.in[0]  <== now_day;   ndayOk.in[1]  <== 32; ndayOk.out  === 1;
    component nmonOk  = LessThan(5); nmonOk.in[0]  <== now_month; nmonOk.in[1]  <== 13; nmonOk.out  === 1;

    // --- has the birthday already occurred this year? ---
    //   month_before = (now_month < dob_month)
    //   month_equal  = (now_month == dob_month)
    //   day_before   = (now_day   < dob_day)
    //   notHadBday   = month_before OR (month_equal AND day_before)
    component monthBefore = LessThan(5);
    monthBefore.in[0] <== now_month;
    monthBefore.in[1] <== dob_month;

    component monthEqual = IsEqual();
    monthEqual.in[0] <== now_month;
    monthEqual.in[1] <== dob_month;

    component dayBefore = LessThan(5);
    dayBefore.in[0] <== now_day;
    dayBefore.in[1] <== dob_day;

    // monthBefore and (monthEqual*dayBefore) are mutually exclusive, so OR == sum.
    signal notHadBday <== monthBefore.out + monthEqual.out * dayBefore.out;

    // --- age from DOB ---
    signal age <== (now_year - dob_year) - notHadBday;

    // --- range predicate: age >= threshold  <=>  age < threshold is FALSE ---
    component ageLt = LessThan(16);
    ageLt.in[0] <== age;
    ageLt.in[1] <== threshold;
    ageLt.out === 0;          // forces age >= threshold; unsatisfiable if underage
    ageGte <== 1;             // public predicate flag (always 1 for an honest proof)

    // --- commitment: reveals nothing about the DOB on its own ---
    component cmt = Poseidon(4);
    cmt.inputs[0] <== dob_year;
    cmt.inputs[1] <== dob_month;
    cmt.inputs[2] <== dob_day;
    cmt.inputs[3] <== salt;
    commitment <== cmt.out;
}

component main {public [now_year, now_month, now_day, threshold]} = AgeGte();
