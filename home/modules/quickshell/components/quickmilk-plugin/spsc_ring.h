#pragma once

#include <vector>
#include <atomic>
#include <cstring>
#include <algorithm>

namespace quickmilk {

struct SpscRing {
    alignas(64) std::vector<float> buf;
    alignas(64) std::atomic<size_t> head{0}; // producer
    alignas(64) std::atomic<size_t> tail{0}; // consumer
    size_t mask; // size must be power-of-two

    explicit SpscRing(size_t pow2_capacity) {
        size_t cap = 1; 
        while (cap < pow2_capacity) cap <<= 1;
        buf.resize(cap);
        mask = cap - 1;
    }
    
    // producer write (audio thread)
    size_t write(const float* src, size_t n) {
        size_t h = head.load(std::memory_order_relaxed);
        size_t t = tail.load(std::memory_order_acquire);
        size_t free = (buf.size() - (h - t));
        n = std::min(n, free);
        for (size_t i = 0; i < n; ++i) {
            buf[(h + i) & mask] = src[i];
        }
        head.store(h + n, std::memory_order_release);
        return n;
    }
    
    // consumer read (UI/processing thread)
    size_t read(float* dst, size_t n) {
        size_t h = head.load(std::memory_order_acquire);
        size_t t = tail.load(std::memory_order_relaxed);
        size_t avail = h - t;
        n = std::min(n, avail);
        for (size_t i = 0; i < n; ++i) {
            dst[i] = buf[(t + i) & mask];
        }
        tail.store(t + n, std::memory_order_release);
        return n;
    }
    
    size_t available() const {
        return head.load(std::memory_order_acquire) - tail.load(std::memory_order_acquire);
    }
};

} // namespace quickmilk