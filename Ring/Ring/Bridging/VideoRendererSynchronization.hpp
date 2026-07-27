/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

#pragma once

#include <atomic>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <utility>

namespace video_renderer {

class State
{
public:
    State(int width, int height, bool hasListeners)
        : width_(width)
        , height_(height)
        , hasListeners_(hasListeners)
    {}

    void updateSize(int width, int height)
    {
        std::lock_guard<std::mutex> lock(sizeMutex_);
        width_ = width;
        height_ = height;
    }

    std::pair<int, int> size() const
    {
        std::lock_guard<std::mutex> lock(sizeMutex_);
        return {width_, height_};
    }

    void setHasListeners(bool hasListeners)
    {
        hasListeners_.store(hasListeners, std::memory_order_relaxed);
    }

    bool shouldRender() const
    {
        return active_.load(std::memory_order_acquire)
            && hasListeners_.load(std::memory_order_relaxed);
    }

    void deactivate()
    {
        active_.store(false, std::memory_order_release);
    }

private:
    mutable std::mutex sizeMutex_;
    int width_;
    int height_;
    std::atomic_bool hasListeners_;
    std::atomic_bool active_ {true};
};

template<typename Value>
class Registry
{
public:
    std::shared_ptr<Value> find(const std::string& id) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto value = values_.find(id);
        return value == values_.end() ? nullptr : value->second;
    }

    std::pair<std::shared_ptr<Value>, bool>
    insertIfAbsent(const std::string& id, std::shared_ptr<Value> value)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto insertion = values_.emplace(id, std::move(value));
        return {insertion.first->second, insertion.second};
    }

    std::shared_ptr<Value> remove(const std::string& id)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto value = values_.find(id);
        if (value == values_.end()) {
            return nullptr;
        }
        auto removedValue = std::move(value->second);
        values_.erase(value);
        return removedValue;
    }

    bool removeIfSame(const std::string& id, const std::shared_ptr<Value>& expected)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto value = values_.find(id);
        if (value == values_.end() || value->second != expected) {
            return false;
        }
        values_.erase(value);
        return true;
    }

private:
    mutable std::mutex mutex_;
    std::map<std::string, std::shared_ptr<Value>> values_;
};

template<typename Owner, typename Callback>
auto makeWeakCallback(const std::shared_ptr<Owner>& owner, Callback callback)
{
    std::weak_ptr<Owner> weakOwner = owner;
    return [weakOwner, callback = std::move(callback)](auto&&... arguments) mutable {
        auto strongOwner = weakOwner.lock();
        if (!strongOwner) {
            return;
        }
        callback(*strongOwner,
                 std::forward<decltype(arguments)>(arguments)...);
    };
}

} // namespace video_renderer
