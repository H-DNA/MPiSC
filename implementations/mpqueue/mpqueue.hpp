#pragma once

#include <cstdio>
#include <cstdlib>
#include <mpi.h>

template <typename T> class MPQueue {
private:
  MPI_Aint _self_rank;
  MPI_Aint _dequeuer_rank;
  MPI_Comm _comm;

public:
  MPQueue(MPI_Aint dequeuer_rank, MPI_Comm comm) {
    int rank;
    MPI_Comm_rank(comm, &rank);
    this->_self_rank = rank;
    this->_dequeuer_rank = dequeuer_rank;
    this->_comm = comm;
  }

  MPQueue(const MPQueue &) = delete;
  MPQueue &operator=(const MPQueue &) = delete;

  MPQueue(MPQueue &&other) noexcept
      : _comm(other._comm), _self_rank(other._self_rank),
        _dequeuer_rank(other._dequeuer_rank) {
    other._comm = MPI_COMM_NULL;
  }

  ~MPQueue() {}

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    MPI_Send(&data, sizeof(T), MPI_BYTE, this->_dequeuer_rank, 0, this->_comm);
    return true;
  }

  bool dequeue(T *output) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    MPI_Status status;
    MPI_Message message;
    int flag;
    MPI_Improbe(MPI_ANY_SOURCE, 0, this->_comm, &flag, &message, &status);

    if (!flag) {
      return false;
    }

    if (flag) {
      MPI_Mrecv(output, sizeof(T), MPI_BYTE, &message, &status);
      return true;
    }

    return false;
  }
};
