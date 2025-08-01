#pragma once

#include "../../active-message-queue/active-message-queue.hpp"
#include "../../ltqueue/ltqueue-node.hpp"
#include "../../ltqueue/ltqueue-unbounded.hpp"
#include "../../ltqueue/ltqueue.hpp"
#include "../../slotqueue/slotqueue-node.hpp"
#include "../../slotqueue/slotqueue-unbounded.hpp"
#include "../../slotqueue/slotqueue.hpp"
#include "bcl/backends/mpi/backend.hpp"
#include "bcl/backends/mpi/comm.hpp"
#include "bcl/core/teams.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <mpi.h>
#include <string>

static void report_isx(std::string title, unsigned long long number_of_elements,
                       int iterations, double total_microseconds) {
  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  if (rank == 0) {
    printf("---- %s ----\n", title.c_str());
    printf("Average latency: %g s\n",
           total_microseconds / iterations / 1000000);
  }
}

inline void slotqueue_isx_sort(unsigned long long number_of_elements,
                               int iterations = 10, bool weak_scaling = false) {
  double microseconds = 0;

  const int MAX_NUM = 10000000;
  const int slice_size = 1 + MAX_NUM / BCL::nprocs();

  auto t1 = std::chrono::high_resolution_clock::now();
  for (int _ = 0; _ < iterations; ++_) {
    std::vector<std::vector<int>> buffers(BCL::nprocs());
    std::vector<SlotQueue<int>> queues;
    for (size_t rank = 0; rank < BCL::nprocs(); rank++) {
      queues.push_back(
          SlotQueue<int>(number_of_elements, rank, MPI_COMM_WORLD));
    }

    const int batch_size = 1024;

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> distr(0, MAX_NUM);
    unsigned long long elements_per_pe =
        weak_scaling ? number_of_elements : number_of_elements / BCL::nprocs();

    for (unsigned long long i = 0; i < elements_per_pe; ++i) {
      int num = distr(gen);
      int slice_index = num / slice_size;
      buffers[slice_index].push_back(num);
      if (buffers[slice_index].size() >= batch_size) {
        queues[slice_index].enqueue(buffers[slice_index]);
        buffers[slice_index].clear();
      }
    }

    for (unsigned long long i = 0; i < buffers.size(); i++) {
      queues[i].enqueue(buffers[i]);
    }

    BCL::barrier();
    int output;
    std::vector<int> my_keys;
    while (queues[BCL::my_rank].dequeue(&output)) {
      my_keys.push_back(output);
    }
    std::sort(my_keys.begin(), my_keys.end());
    BCL::barrier();
  }
  auto t2 = std::chrono::high_resolution_clock::now();
  double local_microseconds =
      std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1).count();

  MPI_Allreduce(&local_microseconds, &microseconds, 1, MPI_DOUBLE, MPI_SUM,
                MPI_COMM_WORLD);
  microseconds /= BCL::nprocs();

  report_isx("Slotqueue", number_of_elements, iterations, microseconds);
}

inline void ltqueue_isx_sort(unsigned long long number_of_elements,
                             int iterations = 10, bool weak_scaling = false) {
  double microseconds = 0;

  const int MAX_NUM = 10000000;
  const int slice_size = 1 + MAX_NUM / BCL::nprocs();

  auto t1 = std::chrono::high_resolution_clock::now();
  for (int _ = 0; _ < iterations; ++_) {
    std::vector<std::vector<int>> buffers(BCL::nprocs());
    std::vector<LTQueue<int>> queues;
    for (size_t rank = 0; rank < BCL::nprocs(); rank++) {
      queues.push_back(
          LTQueue<int>(number_of_elements, rank, MPI_COMM_WORLD));
    }

    const int batch_size = 1024;

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> distr(0, MAX_NUM);
    unsigned long long elements_per_pe =
        weak_scaling ? number_of_elements : number_of_elements / BCL::nprocs();

    for (unsigned long long i = 0; i < elements_per_pe; ++i) {
      int num = distr(gen);
      int slice_index = num / slice_size;
      buffers[slice_index].push_back(num);
      if (buffers[slice_index].size() >= batch_size) {
        queues[slice_index].enqueue(buffers[slice_index]);
        buffers[slice_index].clear();
      }
    }

    for (unsigned long long i = 0; i < buffers.size(); i++) {
      queues[i].enqueue(buffers[i]);
    }

    BCL::barrier();
    int output;
    std::vector<int> my_keys;
    while (queues[BCL::my_rank].dequeue(&output)) {
      my_keys.push_back(output);
    }
    std::sort(my_keys.begin(), my_keys.end());
    BCL::barrier();
  }
  auto t2 = std::chrono::high_resolution_clock::now();
  double local_microseconds =
      std::chrono::duration_cast<std::chrono::microseconds>(t2 - t1).count();

  MPI_Allreduce(&local_microseconds, &microseconds, 1, MPI_DOUBLE, MPI_SUM,
                MPI_COMM_WORLD);
  microseconds /= BCL::nprocs();

  report_isx("LTQueue", number_of_elements, iterations, microseconds);
}
