


**Why This Project Exists** 🚀

After more than a year developing high-performance applications and orchestrating large-scale infrastructure to recover **2, 3, 4, and even 5 missing words** from seeds, one clear limitation emerged with GPU/cluster-based approaches: **the total execution cost scales rapidly**.

In practice, many recoveries only become economically viable when the value at stake is high. At the same time, there is a steady stream of cases involving **smaller amounts** — a few thousand dollars — where the cost (energy, hardware, time, and infrastructure) makes the attempt disproportionate. For **four missing words**, the operation can become unfeasible for most people.

This project was born from that realization: **reduce the marginal cost per attempt** and make legitimate seed recovery **more accessible**, shifting the focus from “expensive brute-force on GPUs” to **energy efficiency and purpose-built hardware**.

---

**FPGA vs GPU: 10 Reasons FPGA Can Be Superior for This Workload** ⚡

1. **Energy Efficiency (Performance per Watt)**  
   For fixed, repetitive algorithms, FPGAs typically deliver a much better work/energy ratio than general-purpose GPUs.

2. **Problem-Specific Dedicated Architecture**  
   In an FPGA, the logic is built to perform exactly the required function — no wasted cycles on unused general-purpose blocks.

3. **Predictable and Deterministic Performance**  
   Stable, repeatable timing makes cost estimation, time planning, and operational control far more reliable.

4. **Reduced Dependency on Software Stack**  
   Minimal reliance on drivers, runtimes, library versions, or ecosystem changes that can introduce instability.

5. **Controlled Scalability via Replication**  
   Capacity can be increased by replicating “lanes” within the chip’s resources, with direct control over area and load balancing.

6. **Fine-Grained Optimization**  
   Critical-path tuning, register balancing, internal organization, and resource/memory usage are fully under control.

7. **Lower Long-Term Operational Cost**  
   In continuous 24/7 operation, savings in electricity and cooling can offset the initial hardware difference.

8. **Lower Heat Generation per Work Unit**  
   Reduced thermal load means lighter requirements for ventilation, cooling, and rack density.

9. **Clear Path to Standardization and Auditability**  
   A deterministic, public design facilitates validation, verification, and transparent evolution — ideal for a community-driven initiative.

10. **Natural Bridge to ASIC**  
    FPGA serves as the perfect validation platform before transitioning to ASIC, where efficiency and cost-per-unit improve dramatically.



<img width="1490" height="889" alt="image" src="https://github.com/user-attachments/assets/4b32b940-6e44-4975-a3a8-efb13362f626" />
No magic here — just circuits doing exactly what you tell them to do. 💻


---

**GPUs Are Excellent — But Energy Cost Is the Real Bottleneck** 🔋

GPUs remain a fantastic choice for rapid prototyping and high initial throughput, backed by a mature ecosystem. However, in long-running, repetitive workloads, **raw speed** gives way to **energy and operational cost** as the dominant factor.

This project prioritizes **efficiency**. In practice: while a modern GPU often runs in the hundreds of watts (sometimes approaching ~600 W), a well-designed FPGA — and especially a dedicated ASIC — can achieve the same goal using a fraction of the power, because it executes only what is strictly necessary.

This approach expands the scope: making recovery economically feasible even for smaller-value cases, not just high-stakes ones.

---

**Project Status** 📊

We are currently defining the core architecture and repository structure. Some code remains experimental and will be progressively organized, tested, and documented as modules stabilize.

Technical contributions, reviews, suggestions, and discussions are very welcome. The goal is to keep this project **public, open, and collaborative**, with verifiable results.

---

**Ethics, Scope, and Methodology (Critical)** 🔒

This project is **strictly** for **legitimate recovery** — never for random seed scanning or unauthorized access. We operate only with clear proof of ownership and explicit consent.

In real cases, intensive computation is always preceded by **forensic and diagnostic work** to drastically reduce the search space responsibly:

- Collection and analysis of old **HDs/SSDs**, USB drives, and local backups (disk images when possible)
- Examination of crypto-related artifacts: old wallets, configs, logs, browser extensions
- Authorized access to client cloud data (Drive/iCloud/OneDrive/Dropbox)
- Compilation of **likely passwords** and usage patterns from the relevant period
- Contextual information: creation date, software/wallet/version/environment
- Any physical evidence: notes, torn paper, partial words, language, estimated word length, etc.

The goal of diagnostics is clear: turn a huge problem into a **much smaller, feasible one** with realistic cost and probability estimates — no false promises.

---

**How You Can Help** 🤝

**Technical Contributions**  
We welcome collaborators experienced in:  
- Applied cryptography and performance engineering  
- Verilog/HDL (FPGA) and synthesis/implementation flows  
- OpenCL (kernel development and optimization)  
- Validation, testing, and benchmarking infrastructure  

Suggestions, reviews, and PRs are highly appreciated.

**Optional Financial Support**  
If you would like to help fund hardware, tools, and prototyping/validation phases:  
Wallet: `bc1qc6yypnwtvfd09ashe73dlg5u3msr5c6xxnxxcv`

**Transparency:** Milestones, goals, and resource usage will be documented publicly whenever possible.  
**Important:** Contributions are voluntary and **not** investment or contractual promises. Any future production plans (including ASIC) depend on technical feasibility, costs, and execution.

PRs, issues, and suggestions are always welcome! 🚀
