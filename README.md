
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

This project ports lock-free Multiple-Producer Single-Consumer (MPSC) queue algorithms from shared-memory to distributed systems using MPI-3 Remote Memory Access (RMA).

### Table of Contents

- [Objective](#objective)
- [Motivation](#motivation)
- [Approach](#approach)
  - [Why MPI RMA?](#why-mpi-rma)
  - [Why MPI-3 RMA?](#why-mpi-3-rma)
  - [Hybrid MPI+MPI](#hybrid-mpimpi)
  - [Hybrid MPI+MPI+C++11](#hybrid-mpimpic11)
  - [Lock-Free MPI Porting](#lock-free-mpi-porting)
- [Literature Review](#literature-review)
  - [Known Problems](#known-problems)
  - [Trends](#trends)
- [Evaluation Strategy](#evaluation-strategy)
  - [Correctness](#correctness)
  - [Lock-Freedom](#lock-freedom)
  - [Performance](#performance)
  - [Scalability](#scalability)
- [Related](#related)

### Objective

- Survey shared-memory literature for lock-free, concurrent MPSC queue algorithms.
- Port candidate algorithms to distributed contexts using MPI-3 RMA.
- Optimize ports using MPI-3 SHM and the C++11 memory model.

Target characteristics:

| Dimension           | Requirement             |
| ------------------- | ----------------------- |
| Queue length        | Fixed                   |
| Number of producers | Multiple                |
| Number of consumers | Single                  |
| Operations          | `enqueue`, `dequeue`    |
| Progress guarantee         | Lock-free               |

### Motivation

Queues are fundamental to scheduling, event handling, and message buffering. Under high contention—such as multiple event sources writing simultaneously—a poorly designed queue becomes a scalability bottleneck. This holds for both shared-memory and distributed systems.

Shared-memory research has produced efficient, scalable, lock-free queue algorithms. Distributed computing literature largely ignores these algorithms due to differing programming models. MPI-3 RMA bridges this gap by enabling one-sided communication that closely mirrors shared-memory semantics. This project investigates whether porting shared-memory algorithms via MPI-3 RMA yields competitive distributed queues.

### Approach

We port lock-free queue algorithms using MPI-3 RMA, then optimize with MPI SHM (hybrid MPI+MPI) and C++11 atomics for intra-node communication.

#### Why MPI RMA?

MPSC queues are *irregular* applications:

- Memory access patterns are dynamic.
- Data locations are determined at runtime.

Traditional two-sided communication (`MPI_Send`/`MPI_Recv`) requires the receiver to anticipate requests—impractical when access patterns are unknown. MPI RMA allows one-sided communication where the initiator specifies all parameters.

#### Why MPI-3 RMA?

MPI-3 introduces `MPI_Win_lock_all`, a non-collective operation for opening access epochs on process groups, enabling lock-free synchronization.

#### Hybrid MPI+MPI

Pure MPI ignores intra-node locality. MPI-3 SHM provides `MPI_Win_allocate_shared` for allocating shared memory windows among co-located processes. These windows use the unified memory model and can leverage both MPI and native synchronization. This exploits multi-core parallelism within nodes.

#### Hybrid MPI+MPI+C++11

C++11 atomics outperform MPI synchronization for intra-node communication. Using C++11 within shared memory windows optimizes the intra-node path.

#### Lock-Free MPI Porting

MPI-3 RMA enables lock-free implementations:

- `MPI_Win_lock_all` / `MPI_Win_unlock_all` manage access epochs.
- MPI atomic operations (`MPI_Fetch_and_op`, `MPI_Compare_and_swap`) provide synchronization.

### Literature Review

#### Known Problems

* **ABA problem**

A pointer is reused after deallocation, causing a CAS to incorrectly succeed.

Solutions: Monotonic counters, hazard pointers.

* **Safe memory reclamation**

Premature deallocation while other threads hold references.

Solutions: Hazard pointers, epoch-based reclamation.

* **Empty queue contention**

Concurrent `enqueue` and `dequeue` on an empty queue can conflict.

Solutions: Sentinel node to separate head and tail pointers.

* **Intermediate state from slow processes**

A delayed process may leave the queue in an inconsistent state mid-operation.

Solutions: Helping—other processes complete the pending operation.

* **Intermediate state from failed processes**

A crashed process may leave the queue permanently inconsistent.

Solutions: Helping mechanisms that can complete any pending operation.

* **Help mechanism rationale**

Multi-step operations can leave the queue in intermediate states. Rather than blocking until consistency is restored, processes detect and complete pending operations. Implementation:

1. Detect intermediate state
2. Attempt completion via CAS

A failed CAS indicates another process already helped; retry is unnecessary.

#### Trends

- Fast-path optimization
  - Lock-free fast path with wait-free fallback
  - Replace CAS with FAA or load/store where possible
- Contention reduction
  - Per-producer local buffers
  - Elimination and backoff (for MPMC)
- Cache-aware design

### Evaluation Strategy

We focus on the following criteria, in the order of decreasing importance:
* Correctness
* Lock-freedom
* Performance & Scalability

#### Correctness

- Linearizability
- ABA-freedom
- Safe memory reclamation

#### Lock-Freedom

No process may block system-wide progress. Note: lock-freedom depends on underlying primitives being lock-free on the target platform.

#### Performance

Minimize latency and maximize throughput for target workloads.

#### Scalability

Throughput should scale with process count.

### Related

- [dLTQueue: A Non-Blocking Distributed-Memory Multi-Producer Single-Consumer Queue](https://www.researchgate.net/publication/395381301_dLTQueue_A_Non-Blocking_Distributed-Memory_Multi-Producer_Single-Consumer_Queue)
- [Slotqueue: A Wait-Free Distributed Multi-Producer Single-Consumer Queue with Constant Remote Operations](https://www.researchgate.net/publication/395448251_Slotqueue_A_Wait-Free_Distributed_Multi-Producer_Single-Consumer_Queue_with_Constant_Remote_Operations)


---

<div align="center">
  <p>
    <small>Last build: Sun Jan 11 03:21:14 UTC 2026</small><br>
    <small>Generated by GitHub Actions • <a href="https://github.com/H-DNA/MPiSC/tree/main">View Source</a></small>
  </p>
</div>
