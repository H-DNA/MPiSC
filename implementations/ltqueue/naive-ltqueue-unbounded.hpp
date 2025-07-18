#pragma once

#include "../lib/comm.hpp"
#include "../lib/distributed-counters/faa.hpp"
#include "../lib/spsc/unbounded_spsc.hpp"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mpi.h>
#include <vector>

template <typename T> class NaiveUnboundedLTQueue {
private:
  struct alignas(8) tree_node_t {
    int32_t rank;
    uint32_t tag;
  };
  constexpr static int32_t DUMMY_RANK = ~((uint32_t)0);

  struct alignas(8) timestamp_t {
    uint32_t timestamp;
    uint32_t tag;
  };
  constexpr static uint32_t MAX_TIMESTAMP = ~((uint32_t)0);

  struct data_t {
    T data;
    uint32_t timestamp;
  };

  MPI_Comm _comm;
  int _self_rank;
  const MPI_Aint _dequeuer_rank;

  FaaCounter _counter;

  MPI_Win _min_timestamp_win;
  timestamp_t *_min_timestamp_ptr;

  MPI_Win _tree_win;
  tree_node_t *_tree_ptr;
  MPI_Info _info;

  UnboundedSpsc<data_t> _spsc;

  int _get_number_of_processes() const {
    int number_processes;
    MPI_Comm_size(this->_comm, &number_processes);

    return number_processes;
  }

  int _get_tree_size() const { return 2 * this->_get_number_of_processes(); }

  int _get_parent_index(int index) const {
    if (index == 0) {
      return -1;
    }
    return (index - 1) / 2;
  }

  int _get_self_index() const {
    return this->_get_number_of_processes() + this->_self_rank;
  }

  int _get_enqueuer_index(int rank) const {
    return this->_get_number_of_processes() + rank;
  }

  std::vector<int> _get_children_indexes(int index) const {
    int left_child = index * 2 + 1;
    int right_child = index * 2 + 2;
    std::vector<int> res;
    if (left_child >= this->_get_tree_size()) {
      return res;
    }
    res.push_back(left_child);
    if (right_child >= this->_get_tree_size()) {
      return res;
    }
    res.push_back(right_child);
    return res;
  }

  // Enqueuer's methods
private:
  void _e_propagate() {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    if (!this->_e_refresh_self_node()) {
      this->_e_refresh_self_node();
    }
    int current_index = this->_get_self_index();
    do {
      current_index = this->_get_parent_index(current_index);
      if (!this->_e_refresh(current_index)) {
        this->_e_refresh(current_index);
      }
    } while (current_index != 0);
  }

  bool _e_refresh_self_node() {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    bool res;
    int self_index = this->_get_self_index();
    tree_node_t self_node;
    timestamp_t min_timestamp;
    aread_sync(&min_timestamp, 0, this->_self_rank, this->_min_timestamp_win);

    aread_sync(&self_node, self_index, this->_dequeuer_rank, this->_tree_win);
    if (min_timestamp.timestamp == MAX_TIMESTAMP) {
      const tree_node_t new_node = {DUMMY_RANK, self_node.tag + 1};
      tree_node_t result_node;
      compare_and_swap_sync(&self_node, &new_node, &result_node, self_index,
                            this->_dequeuer_rank, this->_tree_win);
      res = result_node.rank == self_node.rank &&
            result_node.tag == self_node.tag;
    } else {
      const tree_node_t new_node = {(int32_t)this->_self_rank,
                                    self_node.tag + 1};
      tree_node_t result_node;
      compare_and_swap_sync(&self_node, &new_node, &result_node, self_index,
                            this->_dequeuer_rank, this->_tree_win);
      res = result_node.rank == self_node.rank &&
            result_node.tag == self_node.tag;
    }
    return res;
  }

  bool _e_refresh_timestamp() {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    bool res;

    data_t front;
    bool min_timestamp_succeeded = this->_spsc.e_read_front(&front);

    timestamp_t current_timestamp;
    aread_sync(&current_timestamp, 0, this->_self_rank,
               this->_min_timestamp_win);
    if (!min_timestamp_succeeded) {
      const timestamp_t new_timestamp = {MAX_TIMESTAMP,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      compare_and_swap_sync(&current_timestamp, &new_timestamp,
                            &result_timestamp, 0, this->_self_rank,
                            this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            result_timestamp.timestamp == current_timestamp.timestamp;
    } else {
      const timestamp_t new_timestamp = {front.timestamp,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      compare_and_swap_sync(&current_timestamp, &new_timestamp,
                            &result_timestamp, 0, this->_self_rank,
                            this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            result_timestamp.timestamp == current_timestamp.timestamp;
    }
    return res;
  }

  bool _e_refresh(int current_index) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    tree_node_t current_node;
    uint32_t min_timestamp = MAX_TIMESTAMP;
    int32_t min_timestamp_rank = DUMMY_RANK;
    aread_sync(&current_node, current_index, this->_dequeuer_rank,
               this->_tree_win);
    for (const int child_index : this->_get_children_indexes(current_index)) {
      tree_node_t child_node;
      aread_sync(&child_node, child_index, this->_dequeuer_rank,
                 this->_tree_win);
      if (child_node.rank == DUMMY_RANK) {
        continue;
      }
      timestamp_t child_timestamp;
      aread_sync(&child_timestamp, 0, child_node.rank,
                 this->_min_timestamp_win);
      if (child_timestamp.timestamp < min_timestamp) {
        min_timestamp = child_timestamp.timestamp;
        min_timestamp_rank = child_node.rank;
      }
    }
    const tree_node_t new_node = {min_timestamp_rank, current_node.tag + 1};
    tree_node_t result_node;
    compare_and_swap_sync(&current_node, &new_node, &result_node, current_index,
                          this->_dequeuer_rank, this->_tree_win);
    return result_node.tag == current_node.tag &&
           result_node.rank == current_node.rank;
  }

  // Dequeuer's methods
private:
  bool _d_refresh_timestamp(int enqueuer_rank) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif
    bool res;

    data_t front;
    bool min_timestamp_succeeded =
        this->_spsc.d_read_front(&front, enqueuer_rank);

    timestamp_t current_timestamp;
    aread_sync(&current_timestamp, 0, enqueuer_rank, this->_min_timestamp_win);

    if (!min_timestamp_succeeded) {
      const timestamp_t new_timestamp = {MAX_TIMESTAMP,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      compare_and_swap_sync(&current_timestamp, &new_timestamp,
                            &result_timestamp, 0, enqueuer_rank,
                            this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            result_timestamp.timestamp == current_timestamp.timestamp;
    } else {
      const timestamp_t new_timestamp = {front.timestamp,
                                         current_timestamp.tag + 1};
      timestamp_t result_timestamp;
      compare_and_swap_sync(&current_timestamp, &new_timestamp,
                            &result_timestamp, 0, enqueuer_rank,
                            this->_min_timestamp_win);
      res = result_timestamp.tag == current_timestamp.tag &&
            current_timestamp.timestamp == result_timestamp.timestamp;
    }
    return res;
  }

  bool _d_refresh_self_node(int enqueuer_rank) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    bool res;
    int self_index = this->_get_enqueuer_index(enqueuer_rank);
    tree_node_t self_node;
    timestamp_t min_timestamp;
    aread_sync(&min_timestamp, 0, enqueuer_rank, this->_min_timestamp_win);

    aread_sync(&self_node, self_index, this->_self_rank, this->_tree_win);
    if (min_timestamp.timestamp == MAX_TIMESTAMP) {
      const tree_node_t new_node = {DUMMY_RANK, self_node.tag + 1};
      tree_node_t result_node;
      compare_and_swap_sync(&self_node, &new_node, &result_node, self_index,
                            this->_self_rank, this->_tree_win);
      res = result_node.tag == self_node.tag &&
            result_node.rank == self_node.rank;
    } else {
      const tree_node_t new_node = {enqueuer_rank, self_node.tag + 1};
      tree_node_t result_node;
      compare_and_swap_sync(&self_node, &new_node, &result_node, self_index,
                            this->_self_rank, this->_tree_win);
      res = result_node.tag == self_node.tag &&
            result_node.rank == self_node.rank;
    }
    return res;
  }

  bool _d_refresh(int current_index) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    tree_node_t current_node;
    uint32_t min_timestamp = MAX_TIMESTAMP;
    int32_t min_timestamp_rank = DUMMY_RANK;
    aread_sync(&current_node, current_index, this->_self_rank, this->_tree_win);
    for (const int child_index : this->_get_children_indexes(current_index)) {
      tree_node_t child_node;
      aread_sync(&child_node, child_index, this->_self_rank, this->_tree_win);
      if (child_node.rank == DUMMY_RANK) {
        continue;
      }
      timestamp_t child_timestamp;
      aread_sync(&child_timestamp, 0, child_node.rank,
                 this->_min_timestamp_win);
      if (child_timestamp.timestamp < min_timestamp) {
        min_timestamp = child_timestamp.timestamp;
        min_timestamp_rank = child_node.rank;
      }
    }
    const tree_node_t new_node = {min_timestamp_rank, current_node.tag + 1};
    tree_node_t result_node;
    compare_and_swap_sync(&current_node, &new_node, &result_node, current_index,
                          this->_self_rank, this->_tree_win);
    return result_node.tag == current_node.tag &&
           result_node.rank == current_node.rank;
  }

  void _d_propagate(int enqueuer_rank) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    if (!this->_d_refresh_self_node(enqueuer_rank)) {
      this->_d_refresh_self_node(enqueuer_rank);
    }
    int current_index = this->_get_enqueuer_index(enqueuer_rank);
    do {
      current_index = this->_get_parent_index(current_index);
      if (!this->_d_refresh(current_index)) {
        this->_d_refresh(current_index);
      }
    } while (current_index != 0);
  }

public:
  NaiveUnboundedLTQueue(MPI_Aint dequeuer_rank, MPI_Comm comm)
      : _comm{comm}, _dequeuer_rank{dequeuer_rank}, _spsc{dequeuer_rank, comm},
        _counter{dequeuer_rank, comm} {

    MPI_Comm_rank(comm, &this->_self_rank);
    MPI_Info_create(&this->_info);
    MPI_Info_set(this->_info, "same_disp_unit", "true");
    MPI_Info_set(this->_info, "accumulate_ordering", "none");

    if (this->_self_rank == this->_dequeuer_rank) {
      MPI_Win_allocate(sizeof(timestamp_t), sizeof(timestamp_t), this->_info,
                       comm, &this->_min_timestamp_ptr,
                       &this->_min_timestamp_win);
      MPI_Win_allocate(this->_get_tree_size() * sizeof(tree_node_t),
                       sizeof(tree_node_t), this->_info, comm, &this->_tree_ptr,
                       &this->_tree_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_min_timestamp_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tree_win);

      for (int i = 0; i < this->_get_tree_size(); ++i) {
        this->_tree_ptr[i] = {DUMMY_RANK, 0};
      }

      const timestamp_t start_timestamp = {MAX_TIMESTAMP, 0};
      for (int i = 0; i < this->_get_number_of_processes(); ++i) {
        awrite_async(&start_timestamp, i, this->_self_rank,
                     this->_min_timestamp_win);
      }
    } else {
      MPI_Win_allocate(sizeof(timestamp_t), sizeof(timestamp_t), this->_info,
                       comm, &this->_min_timestamp_ptr,
                       &this->_min_timestamp_win);
      MPI_Win_allocate(0, sizeof(tree_node_t), this->_info, comm,
                       &this->_tree_ptr, &this->_tree_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_min_timestamp_win);
      MPI_Win_lock_all(MPI_MODE_NOCHECK, this->_tree_win);
    }
    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Win_flush_all(this->_tree_win);
    MPI_Barrier(comm);
    MPI_Win_flush_all(this->_min_timestamp_win);
    MPI_Win_flush_all(this->_tree_win);
  }

  NaiveUnboundedLTQueue(const NaiveUnboundedLTQueue &) = delete;
  NaiveUnboundedLTQueue &operator=(const NaiveUnboundedLTQueue &) = delete;
  NaiveUnboundedLTQueue(NaiveUnboundedLTQueue &&other) noexcept
      : _comm{other._comm}, _self_rank{other._self_rank},
        _dequeuer_rank{other._dequeuer_rank},
        _counter{std::move(other._counter)},
        _min_timestamp_win{other._min_timestamp_win},
        _min_timestamp_ptr{other._min_timestamp_ptr},
        _tree_win{other._tree_win}, _tree_ptr{other._tree_ptr},
        _info{other._info}, _spsc{std::move(other._spsc)} {

    other._min_timestamp_win = MPI_WIN_NULL;
    other._min_timestamp_ptr = nullptr;
    other._tree_win = MPI_WIN_NULL;
    other._tree_ptr = nullptr;
    other._info = MPI_INFO_NULL;
  }

  ~NaiveUnboundedLTQueue() {
    if (_min_timestamp_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(this->_min_timestamp_win);
      MPI_Win_free(&this->_min_timestamp_win);
    }
    if (_tree_win != MPI_WIN_NULL) {
      MPI_Win_unlock_all(this->_tree_win);
      MPI_Win_free(&this->_tree_win);
    }
    if (_info != MPI_INFO_NULL) {
      MPI_Info_free(&this->_info);
    }
  }

  bool enqueue(const T &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    uint32_t timestamp = this->_counter.get_and_increment();
    if (!this->_spsc.enqueue({data, timestamp})) {
      return false;
    }

    data_t front;
    uint32_t cur_timestamp;
    if (!this->_spsc.e_read_front(&front)) {
      cur_timestamp = MAX_TIMESTAMP;
    } else {
      cur_timestamp = front.timestamp;
    }
    if (cur_timestamp != timestamp) {
      return true;
    }

    if (!this->_e_refresh_timestamp()) {
      this->_e_refresh_timestamp();
    }
    this->_e_propagate();
    return true;
  }

  bool enqueue(const std::vector<T> &data) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    if (data.size() == 0) {
      return true;
    }
    uint32_t timestamp = this->_counter.get_and_increment();
    std::vector<data_t> timestamped_data;
    for (const T &datum : data) {
      timestamped_data.push_back(data_t{datum, timestamp});
    }
    if (!this->_spsc.enqueue(timestamped_data)) {
      return false;
    }

    if (!this->_e_refresh_timestamp()) {
      this->_e_refresh_timestamp();
    }
    this->_e_propagate();
    return true;
  }

  bool dequeue(T *output) {
#ifdef PROFILE
    CALI_CXX_MARK_FUNCTION;
#endif

    tree_node_t root;
    aread_sync(&root, 0, this->_self_rank, this->_tree_win);

    if (root.rank == DUMMY_RANK) {
      return false;
    }
    data_t spsc_output;
    if (!this->_spsc.dequeue(&spsc_output, root.rank)) {
      return false;
    }
    if (!this->_d_refresh_timestamp(root.rank)) {
      this->_d_refresh_timestamp(root.rank);
    }
    this->_d_propagate(root.rank);
    *output = spsc_output.data;
    return true;
  }
};
