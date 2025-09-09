#pragma once

#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <vector>

template <typename T> class LQueue {
private:
  MPI_Aint _capacity;
  int _self_rank;
  MPI_Comm _comm;
  MPI_Aint _dequeuer_rank;
  MPI_Info _info;

  MPI_Win _counter_win;
  MPI_Aint *_counter_ptr;
  MPI_Win _data_win;
  T *_data_ptr;

public:
  LQueue(MPI_Aint total_capacity, MPI_Aint dequeuer_rank, MPI_Comm comm)
      : _capacity{total_capacity}, _comm{comm}, _dequeuer_rank{dequeuer_rank} {
    MPI_Comm_rank(comm, &this->_self_rank);

    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (this->_self_rank == dequeuer_rank) {
      MPI_Win_allocate(total_capacity * sizeof(T), sizeof(T), this->_info, comm,
                       &this->_data_ptr, &this->_data_win);
      MPI_Win_allocate(sizeof(MPI_Aint), sizeof(MPI_Aint), this->_info, comm,
                       &this->_counter_ptr, &this->_counter_win);
      *_counter_ptr = 0;
    } else {
      MPI_Win_allocate(0, sizeof(T), this->_info, comm, &this->_data_ptr,
                       &this->_data_win);
      MPI_Win_allocate(0, sizeof(MPI_Aint), this->_info, comm,
                       &this->_counter_ptr, &this->_counter_win);
    }
    MPI_Win_flush_all(this->_data_win);
    MPI_Win_flush_all(this->_counter_win);
  }

  LQueue(const LQueue &) = delete;
  LQueue &operator=(const LQueue &) = delete;

  LQueue(LQueue &&other) noexcept
      : _comm(other._comm), _self_rank(other._self_rank),
        _capacity(other._capacity), _dequeuer_rank(other._dequeuer_rank),
        _info(other._info), _counter_win(other._counter_win),
        _counter_ptr(other._counter_ptr), _data_win(other._data_win),
        _data_ptr(other._data_ptr) {
    other._counter_win = MPI_WIN_NULL;
    other._counter_ptr = nullptr;
    other._data_win = MPI_WIN_NULL;
    other._data_ptr = nullptr;
    other._comm = MPI_COMM_NULL;
    other._info = MPI_INFO_NULL;
  }

  ~LQueue() {
    if (this->_counter_win != MPI_WIN_NULL) {
      MPI_Win_free(&this->_counter_win);
    }
    if (this->_data_win != MPI_WIN_NULL) {
      MPI_Win_free(&this->_data_win);
    }
  }

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    MPI_Win_lock(MPI_LOCK_SHARED, this->_dequeuer_rank, 0, this->_counter_win);
    MPI_Win_lock(MPI_LOCK_SHARED, this->_dequeuer_rank, 0, this->_data_win);

    MPI_Aint old_counter;
    MPI_Aint increment = 1;
    MPI_Fetch_and_op(&increment, &old_counter, MPI_AINT, this->_dequeuer_rank,
                     0, MPI_SUM, this->_counter_win);

    MPI_Win_flush(this->_dequeuer_rank, this->_counter_win);

    if (old_counter >= this->_capacity) {
      MPI_Aint decrement = -1;
      MPI_Accumulate(&decrement, 1, MPI_AINT, this->_dequeuer_rank, 0, 1,
                     MPI_AINT, MPI_SUM, this->_counter_win);
      MPI_Win_flush(this->_dequeuer_rank, this->_counter_win);

      MPI_Win_unlock(this->_dequeuer_rank, this->_data_win);
      MPI_Win_unlock(this->_dequeuer_rank, this->_counter_win);
      return false;
    }

    MPI_Put(&data, sizeof(T), MPI_BYTE, this->_dequeuer_rank, old_counter,
            sizeof(T), MPI_BYTE, this->_data_win);

    MPI_Win_flush(this->_dequeuer_rank, this->_data_win);

    MPI_Win_unlock(this->_dequeuer_rank, this->_data_win);
    MPI_Win_unlock(this->_dequeuer_rank, this->_counter_win);

    return true;
  }

  bool dequeue(std::vector<T> &output) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    MPI_Win_lock(MPI_LOCK_EXCLUSIVE, this->_dequeuer_rank, 0,
                 this->_counter_win);
    MPI_Win_lock(MPI_LOCK_EXCLUSIVE, this->_dequeuer_rank, 0, this->_data_win);

    MPI_Aint current_counter = *this->_counter_ptr;

    if (current_counter == 0) {
      MPI_Win_unlock(this->_dequeuer_rank, this->_data_win);
      MPI_Win_unlock(this->_dequeuer_rank, this->_counter_win);
      return false;
    }

    *this->_counter_ptr = 0;
    output.resize(current_counter);
    for (MPI_Aint i = 0; i < current_counter; ++i) {
      output[i] = this->_data_ptr[i];
    }

    MPI_Win_flush_local(this->_dequeuer_rank, this->_counter_win);
    MPI_Win_flush_local(this->_dequeuer_rank, this->_data_win);

    MPI_Win_unlock(this->_dequeuer_rank, this->_data_win);
    MPI_Win_unlock(this->_dequeuer_rank, this->_counter_win);

    return true;
  }
};
