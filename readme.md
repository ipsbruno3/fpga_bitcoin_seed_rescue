# 🔐 FPGA Bitcoin Seed Rescue

![Verilog](https://img.shields.io/badge/Verilog-HDL-blue)
![FPGA](https://img.shields.io/badge/Platform-FPGA%20%2F%20ASIC-green)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Status](https://img.shields.io/badge/Status-Tested-brightgreen)

>  **⚡ Energy-Efficient Hardware Acceleration of Bitcoin BIP-39 for Seed Phrase Recovery**

## 📖 Overview

This repository collects Verilog hardware blocks to recover BIP-39 seeds in an **energy-efficient** way, using FPGA/ASIC instead of GPU clusters. The idea is to reduce the marginal cost per attempt and make legitimate recoveries viable for wallets that lost 2–5 words or for small amounts that do not justify expensive infrastructure.

- **Focus:** SHA-256/SHA-512 pipelines, PBKDF2-HMAC-SHA512 derivation, and BIP-39 word generation from 128-bit entropy.
- **Ethical use:** only for recovery with proof of ownership and explicit consent.

---


### 🎯 Files overview

| File | Role | What it does |
| --- | --- | --- |
| `generate.sv` | BIP-39 word generation | Converts 128 bits of entropy + checksum into 12 indices of 11 bits and looks up each word in the ROM. Includes `tb_words_stream_12`, a testbench that calculates the checksum via `sha256_firstbyte_128`, drives the flow, and prints the full phrase. |
| `sha256.sv` | Compact SHA-256 (1 block) | Implements `sha256_firstbyte_128`, a simple engine that processes 128 bits of entropy (plus padding) and exposes only the **first byte of the digest**, used as a 4-bit checksum in word generation. Signals `busy/done` for easy hardware control. |
| `pbkdf_10_cycles.sv` | Iterative PBKDF2 (10 cycles per compression) | Proof of concept of PBKDF2-HMAC-SHA512 for the password and salt "mnemonic." Uses a 10-cycle SHA-512 core (`sha512_10cycle`) and an FSM that iterates 2048 times, accumulating `T` with XOR of blocks U1..U2048. Includes a testbench that compares the output with the official vector. |
| `pbkdf_combinational.sv` | Combinational PBKDF2 | Alternative version for the same test case "mnemonic" but using combinational SHA-512 compressions (one cycle per block). Keeps the same validation testbench for seed derivation. |

---

## How the pieces fit together

1. **12-word phrase generation**
   - The `pack_128plus4_to_12x11` module (in `generate.sv`) slices 128 bits of entropy plus 4 bits of checksum into 12 BIP-39 indices.
   - `words_stream_12` sequences these indices to the word ROM (`palavras_rom`) and returns each word as a 72-bit vector, with `word_valid` pulsing for each output and `done` asserted after all 12 words.
   - The `tb_words_stream_12` testbench computes the checksum with `sha256_firstbyte_128`, applies the input, and prints the formatted phrase, serving as an integration example between SHA-256 and the word generator.

2. **PBKDF2-HMAC-SHA512 derivation**
   - Both `pbkdf_10_cycles.sv` and `pbkdf_combinational.sv` implement the standard BIP-39 seed derivation (password = salt = "mnemonic" and 2048 iterations), differing only in the SHA-512 core architecture (10-cycle pipelined vs. combinational block).
   - Each version includes a testbench that asserts `start`, waits for `done`, and compares `seed_out` with the expected vector, printing PASS/FAIL in simulation.

3. **SHA-256 for checksum**
   - `sha256_firstbyte_128` processes a 128-bit message (plus internal padding) and provides the first byte of the digest. The testbench in `generate.sv` uses bits [7:4] as the BIP-39 checksum, ensuring valid phrases.

---

## Current status and next steps

- The modules already simulate the essential flows (word generation and PBKDF2). Parts of the code are experimental and may be restructured for pipelines, multiple parallel instances, and integration with the full word ROM.
- Contributions are welcome for optimization (latency × area), integration with FPGA/ASIC toolflows, and test coverage.

---

## Collaboration and ethics

- **Contribute technically:** Verilog/HDL, applied crypto, synthesis/implementation flows, validation, and benchmarking.
- **Optional support:** `bc1qc6yypnwtvfd09ashe73dlg5u3msr5c6xxnxxcv` (transparency about resource use will be prioritized).
- **Responsible use:** Only legitimate recovery, with proof and consent. Each case should start with diagnostics (digital artifacts, context, likely passwords) to reduce the search space before spending computational energy.




## 📧 Contact

For questions, suggestions, or collaboration opportunities:

**Email**: 📩 [bsbruno@proton.me](mailto:bsbruno@proton.me)

---

## 📄 License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**⭐ If this project helped you, please consider giving it a star! ⭐**

Made with ❤️ for the hardware security community

</div>


PRs, issues, and suggestions are always welcome! 🚀
