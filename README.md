
<div align="center">
  <h3>Automatically Generated PDF Documents</h3>
  <p>
    <em>This site hosts the compiled PDF files from the Typst project source files of <a href="https://github.com/Huy-DNA/MPiSC/tree/main">MPiSC</a>.</em>
  </p>
</div>

---

## 📄 Available Documents

<table>
  <thead>
    <tr>
      <th align="left">Document</th>
      <th align="left">Last Content Update</th>
      <th align="center">View</th>
      <th align="center">Download</th>
    </tr>
  </thead>
  <tbody>
      <tr>
        <td><strong>           Studying and developing nonblocking distributed MPSC queues</strong></td>
        <td>2026-01-11</td>
        <td align="center"><a href="report/main.pdf">📕 View</a></td>
        <td align="center"><a href="report/main.pdf" download>⬇️ PDF</a></td>
      </tr>
    </tbody>
  </table>

## 📝 Project Information



![MPiSC](https://img.shields.io/badge/MPiSC-blue?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyTDIgN2wxMCA1IDEwLTV6TTIgMTdsMTAgNSAxMC01TTIgMTJsMTAgNSAxMC01Ii8+PC9zdmc+) ![Status](https://img.shields.io/badge/status-complete-brightgreen) [![Thesis](https://img.shields.io/badge/thesis-h--dna.github.io-informational)](https://h-dna.github.io/MPiSC/)

### Table of Contents

- [Abstract](#abstract)
- [Motivation and Methodology](#motivation-and-methodology)
- [Contributions](#contributions)
- [Results](#results)
- [Related](#related)

### Abstract

Distributed applications such as the actor model and fan-out/fan-in pattern require MPSC queues that are both performant and fault-tolerant. We address the absence of non-blocking distributed MPSC queues by adapting LTQueue — a wait-free shared-memory MPSC queue — to distributed environments using MPI-3 RMA. We introduce three novel **wait-free** distributed MPSC queues: **dLTQueue**, **Slotqueue**, and **dLTQueueV2**. Evaluation on SuperMUC-NG and CoolMUC-4 shows ~2x better enqueue throughput than the existing AMQueue while providing stronger fault tolerance.

### Motivation and Methodology

#### The Problem

MPSC queues are essential for **irregular applications** — programs with unpredictable, data-dependent memory access patterns:

- **Actor model**: Each actor maintains a mailbox (MPSC queue) receiving messages from other actors
- **Fan-out/fan-in**: Worker nodes enqueue results to an aggregation node for processing

These patterns demand queues that are both performant and fault-tolerant. A slow or crashed producer should not block the entire system.

#### Gap in the Literature

**Shared-memory** has several non-blocking MPSC queues: LTQueue, DQueue, WRLQueue, and Jiffy. However, our analysis reveals critical flaws in most:

| Queue | Issue |
|-------|-------|
| DQueue | Incorrect ABA solution and unsafe memory reclamation |
| WRLQueue | Actually **blocking** — dequeuer waits for all enqueuers |
| Jiffy | Insufficient memory reclamation, not truly wait-free |
| **LTQueue** | **Correct** — uses LL/SC for ABA, proper memory reclamation |

**Distributed** has only one MPSC queue: **AMQueue**. Despite claiming lock-freedom, it is actually **blocking** — the dequeuer must wait for all enqueuers to finish. A single slow enqueuer halts the entire system. ([Confirmed by the original author](assets/amqueue-blocking-evidence.png))

#### Our Approach

We adapt **LTQueue** — the only correct shared-memory MPSC queue — to distributed environments using MPI-3 RMA one-sided communication.

**Key challenge**: LTQueue relies on LL/SC (Load-Link/Store-Conditional) to solve the ABA problem, but LL/SC is unavailable in MPI.

**Our solution**: Replace LL/SC with CAS + unique timestamps. Each value is tagged with a monotonically increasing version number, preventing ABA without LL/SC.

**Key techniques**:
- **SPSC-per-enqueuer**: Each producer maintains a local queue, eliminating producer contention
- **Unique timestamps**: Solves ABA via monotonic version numbers
- **Double-refresh**: Bounds retries to two per node, ensuring wait-freedom

### Contributions

#### Findings

- **3 of 4** shared-memory MPSC queues (DQueue, WRLQueue, Jiffy) have correctness or progress issues
- **AMQueue**, the only distributed MPSC queue, is blocking despite claims of lock-freedom
- **LTQueue** is the only correct candidate for distributed adaptation

#### Novel Algorithms

| Algorithm | Progress | Enqueue | Dequeue |
|-----------|----------|---------|---------|
| **dLTQueue** | Wait-free | O(log n) remote | O(log n) remote |
| **Slotqueue** | Wait-free | O(1) remote | O(1) remote, O(n) local |
| **dLTQueueV2** | Wait-free | O(1) remote | O(1) remote, O(log n) local |

All algorithms are **linearizable** with no dynamic memory allocation.

### Results

Benchmarked on [SuperMUC-NG](https://doku.lrz.de/supermuc-ng-10745965.html) (6000+ nodes) and [CoolMUC-4](https://doku.lrz.de/coolmuc-4-10746415.html) (100+ nodes):

| Metric | Our Queues vs AMQueue |
|--------|----------------------|
| Enqueue throughput | **~2x better** |
| Dequeue throughput | 3-10x worse |
| Fault tolerance | **Wait-free** (vs blocking) |

**Trade-off**: Stronger fault tolerance at the cost of dequeue performance.

### Related

1. **dLTQueue** - FDSE 2025 ([ResearchGate](https://www.researchgate.net/publication/395381301_dLTQueue_A_Non-Blocking_Distributed-Memory_Multi-Producer_Single-Consumer_Queue))
2. **Slotqueue** - NPC 2025 ([ResearchGate](https://www.researchgate.net/publication/395448251_Slotqueue_A_Wait-Free_Distributed_Multi-Producer_Single-Consumer_Queue_with_Constant_Remote_Operations))

[Full thesis](https://h-dna.github.io/MPiSC/)


---

<div align="center">
  <p>
    <small>Last build: Sun Jan 11 17:10:09 UTC 2026</small><br>
    <small>Generated by GitHub Actions • <a href="https://github.com/H-DNA/MPiSC/tree/main">View Source</a></small>
  </p>
</div>
