#!/usr/bin/env node
// ============================================================================
// Veritas — zk_helpers.js : crypto glue between Python harness and the circuits
// ============================================================================
// Single Node CLI that wraps circomlibjs to do exactly the crypto the circom
// circuits expect, so the Python test harness does not have to re-implement
// BabyJubJub / EdDSA / Poseidon. All field elements are printed as DECIMAL
// STRINGS (the format circom/snarkjs input.json expects).
//
// Subcommands:
//   genkey [--prv HEX]                          -> {prv, Ax, Ay}
//   sign   --prv HEX --field N --secret N       -> {Ax,Ay,R8x,R8y,S,nullifier,msg}
//   merkle --depth N --members "1,2,..." --prove INDEX
//                                               -> {depth,root,leaf,pathElements,pathIndices}
//   poseidon --args "a,b,c"                     -> {out}
//
// These helpers are DEMO / TEST ONLY. The issuer private key is a test key,
// generated in-repo, clearly NOT for production.
// ============================================================================
"use strict";

const { buildPoseidonOpt, buildEddsa } = require("circomlibjs");

function parseArgs(argv) {
    const out = {};
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith("--")) {
            const key = a.slice(2);
            const val = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : "true";
            out[key] = val;
        }
    }
    return out;
}

// left child = current node when idx bit is 0; right child when bit is 1.
// MUST match circuits/lib/merkle_poseidon.circom exactly.
function merkleProof(F, poseidon, leaves, depth, index) {
    const n = 2 ** depth;
    if (index >= n) throw new Error(`index ${index} out of range for depth ${depth}`);

    // pad leaves up to n elements; use the leaf for padding (so unused slots are
    // harmless duplicates of member 0) — does not affect the real members.
    const pad = leaves.slice();
    const padLeaf = leaves.length ? leaves[0] : 0n;
    while (pad.length < n) pad.push(padLeaf);

    const pathElements = [];
    const pathIndices = [];

    let level = pad.map((x) => BigInt(x));
    let idx = index;

    for (let lvl = 0; lvl < depth; lvl++) {
        const sibIdx = idx ^ 1;
        pathElements.push(level[sibIdx].toString());
        pathIndices.push(idx & 1); // 0 => current is left, 1 => current is right
        const next = [];
        for (let j = 0; j < level.length; j += 2) {
            next.push(BigInt(F.toObject(poseidon([level[j], level[j + 1]]))));
        }
        level = next;
        idx = idx >> 1;
    }
    const root = level[0].toString();
    return { root, pathElements, pathIndices };
}

async function main() {
    const args = parseArgs(process.argv.slice(2));
    const cmd = process.argv[2];
    if (!cmd || cmd.startsWith("--")) {
        console.error("usage: zk_helpers.js <genkey|sign|merkle|poseidon> [opts]");
        process.exit(2);
    }

    const poseidon = await buildPoseidonOpt();
    const eddsa = await buildEddsa();
    const F = poseidon.F;

    if (cmd === "poseidon") {
        const vals = (args.args || "").split(",").map((s) => BigInt(s.trim()));
        const out = F.toObject(poseidon(vals));
        console.log(JSON.stringify({ inputs: vals.map(String), out: out.toString() }));
        return;
    }

    if (cmd === "genkey") {
        const prvHex =
            args.prv ||
            Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString("hex");
        const prv = Buffer.from(prvHex, "hex");
        const pub = eddsa.prv2pub(prv);
        console.log(
            JSON.stringify({
                prv: prvHex,
                Ax: F.toObject(pub[0]).toString(),
                Ay: F.toObject(pub[1]).toString(),
            })
        );
        return;
    }

    if (cmd === "sign") {
        if (!args.prv || args.field === undefined || args.secret === undefined) {
            console.error("sign requires --prv --field --secret");
            process.exit(2);
        }
        const prv = Buffer.from(args.prv, "hex");
        const pub = eddsa.prv2pub(prv);
        const field = BigInt(args.field);
        const secret = BigInt(args.secret);
        const msg = poseidon([field, secret]); // m = Poseidon(field, secret)
        const sig = eddsa.signPoseidon(prv, msg);
        const nullifier = F.toObject(poseidon([secret]));
        console.log(
            JSON.stringify({
                field: field.toString(),
                secret: secret.toString(),
                Ax: F.toObject(pub[0]).toString(),
                Ay: F.toObject(pub[1]).toString(),
                R8x: F.toObject(sig.R8[0]).toString(),
                R8y: F.toObject(sig.R8[1]).toString(),
                S: sig.S.toString(),
                msg: F.toObject(msg).toString(),
                nullifier: nullifier.toString(),
            })
        );
        return;
    }

    if (cmd === "merkle") {
        const depth = parseInt(args.depth || "8", 10);
        const members = (args.members || "").split(",").map((s) => BigInt(s.trim()));
        const idx = parseInt(args.prove !== undefined ? args.prove : "0", 10);
        if (members.length > 2 ** depth) {
            console.error(`too many members (${members.length}) for depth ${depth}`);
            process.exit(2);
        }
        if (idx >= members.length) {
            console.error(`prove index ${idx} out of range (have ${members.length} members)`);
            process.exit(2);
        }
        const pf = merkleProof(F, poseidon, members, depth, idx);
        console.log(
            JSON.stringify({
                depth,
                members: members.map(String),
                proveIndex: idx,
                leaf: members[idx] !== undefined ? members[idx].toString() : null,
                root: pf.root.toString(),
                pathElements: pf.pathElements.map(String),
                pathIndices: pf.pathIndices.map(String),
            })
        );
        return;
    }

    console.error("unknown command: " + cmd);
    process.exit(2);
}

main().catch((e) => {
    console.error("ERROR:", e.stack || e.message || e);
    process.exit(1);
});
