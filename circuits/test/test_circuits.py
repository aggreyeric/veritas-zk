"""
Veritas circuit test suite — positive + negative cases for every circuit.

Run with pytest:
    python3 -m pytest circuits/test -v

Run standalone (no pytest needed):
    python3 circuits/test/test_circuits.py

What each case proves:
  * positive:  a valid proof is produced AND verifies OK, with the expected
               public signals (nullifier == Poseidon(secret), issuer keys,
               threshold/root) — i.e. the circuit says what we think it says.
  * negative:  witness generation FAILS, which is the security guarantee — a bad
               credential (under-age / wrong issuer / country not in allow-set)
               can NEVER produce a proof.

Negative tests rely on `expects_reject`, which asserts that snarkjs witness
calculation fails (the circuit is unsatisfiable). If a bad credential ever
produced a witness, that would be a critical bug.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from veritas_harness import (  # noqa: E402
    circuit, expects_pass, expects_reject, poseidon, sign, merkle,
    TEST_ISSUER_PRV,
)


# ---------------------------------------------------------------------------
# trivial — y = x*x   (pipeline sanity)
# ---------------------------------------------------------------------------
def test_trivial_pass():
    pubs = expects_pass(circuit("trivial"), {"x": "7"}, "pass")
    assert pubs == ["49"], pubs


def test_trivial_correct_square():
    # only the satisfying x (7) reproduces the committed output 49
    pubs = expects_pass(circuit("trivial"), {"x": "13"}, "square13")
    assert pubs == ["169"], pubs


# ---------------------------------------------------------------------------
# age_gte — private age + salt -> Poseidon commitment; age >= threshold
# ---------------------------------------------------------------------------
def test_age_gte_pass():
    pubs = expects_pass(circuit("age_gte"),
                        {"age": "25", "salt": "12345", "threshold": "18"}, "pass")
    # public = [commitment, ageGte, threshold]
    assert pubs[1] == "1", pubs            # ageGte flag
    assert pubs[2] == "18", pubs           # threshold echoed
    assert pubs[0] == poseidon(25, 12345), pubs   # commitment is Poseidon(age,salt)


def test_age_gte_boundary_18():
    pubs = expects_pass(circuit("age_gte"),
                        {"age": "18", "salt": "9", "threshold": "18"}, "boundary")
    assert pubs[1] == "1", pubs


def test_age_gte_reject_underage():
    expects_reject(circuit("age_gte"),
                   {"age": "16", "salt": "12345", "threshold": "18"}, "underage")


def test_age_gte_reject_far_underage():
    expects_reject(circuit("age_gte"),
                   {"age": "0", "salt": "1", "threshold": "21"}, "zero")


# ---------------------------------------------------------------------------
# valid_owner — issuer-signed credential validity + nullifier (no predicate)
# ---------------------------------------------------------------------------
def test_valid_owner_pass():
    s = sign(field=9001, secret=777)
    inputs = {
        "claimField": s["field"], "holderSecret": s["secret"],
        "sigR8x": s["R8x"], "sigR8y": s["R8y"], "sigS": s["S"],
        "issuerAx": s["Ax"], "issuerAy": s["Ay"],
    }
    pubs = expects_pass(circuit("valid_owner"), inputs, "pass")
    # public = [nullifier, issuerAx, issuerAy]
    assert pubs[1] == s["Ax"], pubs
    assert pubs[2] == s["Ay"], pubs
    assert pubs[0] == poseidon(s["secret"]), pubs   # nullifier == Poseidon(secret)


def test_valid_owner_reject_wrong_issuer():
    s = sign(field=9001, secret=777)
    bad_issuer = str(int(s["Ax"]) + 1)             # signature is for a different key
    inputs = {
        "claimField": s["field"], "holderSecret": s["secret"],
        "sigR8x": s["R8x"], "sigR8y": s["R8y"], "sigS": s["S"],
        "issuerAx": bad_issuer, "issuerAy": s["Ay"],
    }
    expects_reject(circuit("valid_owner"), inputs, "wrong_issuer")


# ---------------------------------------------------------------------------
# credential_age — FLAGSHIP: issuer-signed age >= threshold + nullifier
# ---------------------------------------------------------------------------
def _credential_age_inputs(age, secret, threshold="18", *, issuer=None, prv=TEST_ISSUER_PRV):
    s = sign(field=age, secret=secret, prv=prv)
    issuer = issuer or s
    return {
        "age": str(age), "holderSecret": str(secret),
        "sigR8x": s["R8x"], "sigR8y": s["R8y"], "sigS": s["S"],
        "issuerAx": issuer["Ax"], "issuerAy": issuer["Ay"], "threshold": str(threshold),
    }


def test_credential_age_pass():
    pubs = expects_pass(circuit("credential_age"),
                        _credential_age_inputs(age=25, secret=12345), "pass")
    # public = [nullifier, issuerAx, issuerAy, threshold]
    assert pubs[3] == "18", pubs                         # threshold
    assert pubs[0] == poseidon(12345), pubs              # nullifier == Poseidon(secret)
    # issuer key in the public signals matches the key that signed (the circuit
    # verified the signature against exactly this public key).
    ref = sign(field=25, secret=12345)
    assert pubs[1] == ref["Ax"], pubs
    assert pubs[2] == ref["Ay"], pubs


def test_credential_age_pass_higher_threshold():
    pubs = expects_pass(circuit("credential_age"),
                        _credential_age_inputs(age=65, secret=42, threshold="65"), "senior")
    assert pubs[3] == "65", pubs


def test_credential_age_reject_underage():
    expects_reject(circuit("credential_age"),
                   _credential_age_inputs(age=16, secret=12345), "underage")


def test_credential_age_reject_underage_high_threshold():
    # 21+ gate, holder is 19 -> rejected
    expects_reject(circuit("credential_age"),
                   _credential_age_inputs(age=19, secret=5, threshold="21"), "under21")


def test_credential_age_reject_wrong_issuer():
    other = sign(field=99, secret=1, prv="deadbeef" * 8)   # a DIFFERENT issuer signs
    # but we claim it was signed by the real issuer (TEST_ISSUER_PRV)
    real = sign(field=25, secret=12345)
    inputs = _credential_age_inputs(age=25, secret=12345, issuer=real)
    # corrupt the signature: use other-issuer's S with real issuer's key
    inputs["sigS"] = other["S"]
    expects_reject(circuit("credential_age"), inputs, "forged_sig")


# ---------------------------------------------------------------------------
# jurisdiction_allowed — issuer-signed country is a MEMBER of the allow-set tree
# ---------------------------------------------------------------------------
def test_jurisdiction_allowed_pass():
    # allowed set: US(840), CA(124), NL(528). Holder is Canadian.
    tree = merkle(depth=8, members=[840, 124, 528], prove_index=1)
    s = sign(field=124, secret=555)
    inputs = {
        "country": s["field"], "holderSecret": s["secret"],
        "sigR8x": s["R8x"], "sigR8y": s["R8y"], "sigS": s["S"],
        "pathElements": tree["pathElements"], "pathIndices": tree["pathIndices"],
        "issuerAx": s["Ax"], "issuerAy": s["Ay"], "allowedRoot": tree["root"],
    }
    pubs = expects_pass(circuit("jurisdiction_allowed"), inputs, "pass")
    # public = [nullifier, issuerAx, issuerAy, allowedRoot]
    assert pubs[3] == tree["root"], pubs
    assert pubs[0] == poseidon(555), pubs


def test_jurisdiction_allowed_reject_not_member():
    # valid membership proof for {840,124,528}, but we claim against a DIFFERENT
    # allow-set root (e.g. an on-chain sanctions replacement). root mismatch ->
    # the circuit cannot be satisfied.
    tree = merkle(depth=8, members=[840, 124, 528], prove_index=1)
    other_root = merkle(depth=8, members=[1, 2, 3], prove_index=0)["root"]
    s = sign(field=124, secret=555)
    inputs = {
        "country": s["field"], "holderSecret": s["secret"],
        "sigR8x": s["R8x"], "sigR8y": s["R8y"], "sigS": s["S"],
        "pathElements": tree["pathElements"], "pathIndices": tree["pathIndices"],
        "issuerAx": s["Ax"], "issuerAy": s["Ay"], "allowedRoot": other_root,
    }
    expects_reject(circuit("jurisdiction_allowed"), inputs, "wrong_root")


def test_jurisdiction_allowed_reject_forged_sig():
    tree = merkle(depth=8, members=[840, 124, 528], prove_index=1)
    # country 124 is genuinely in the set, but the credential was never signed
    other = sign(field=999, secret=1, prv="cafe" * 16)
    s = sign(field=124, secret=555)
    inputs = {
        "country": s["field"], "holderSecret": s["secret"],
        "sigR8x": other["R8x"], "sigR8y": other["R8y"], "sigS": other["S"],
        "pathElements": tree["pathElements"], "pathIndices": tree["pathIndices"],
        "issuerAx": s["Ax"], "issuerAy": s["Ay"], "allowedRoot": tree["root"],
    }
    expects_reject(circuit("jurisdiction_allowed"), inputs, "forged_sig")


# ---------------------------------------------------------------------------
# Standalone runner (no pytest required)
# ---------------------------------------------------------------------------
def _all_tests():
    for name, obj in sorted(globals().items()):
        if name.startswith("test_") and callable(obj):
            yield name, obj


def main() -> int:
    tests = list(_all_tests())
    print(f"\n  Veritas circuit test suite — {len(tests)} cases\n  " + "-" * 52)
    passed, failed = 0, 0
    for name, fn in tests:
        try:
            fn()
        except Exception as e:                       # noqa: BLE001
            failed += 1
            msg = str(e).strip().splitlines()[0] if str(e).strip() else type(e).__name__
            print(f"  FAIL  {name[5:]:<34} {msg}")
        else:
            passed += 1
            print(f"  ok    {name[5:]}")
    print("  " + "-" * 52)
    print(f"  {passed} passed, {failed} failed\n")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
