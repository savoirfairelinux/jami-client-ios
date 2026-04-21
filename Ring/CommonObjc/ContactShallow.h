/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

#pragma once

// Mirror of the daemon's internal `jami::Contact` struct

#define MSGPACK_NO_BOOST
#define MSGPACK_DISABLE_LEGACY_NIL
#import "msgpack.hpp"
#import "opendht/infohash.h"
#include <cstdint>
#include <fstream>
#include <iterator>
#include <map>
#include <string>
#include <vector>

namespace jami_ios {
struct ContactShallow {
    int64_t added {0};
    int64_t removed {0};
    bool confirmed {false};
    bool banned {false};
    std::string conversationId {};
    MSGPACK_DEFINE_MAP(added, removed, confirmed, banned, conversationId)
};

inline std::map<dht::InfoHash, ContactShallow> readContactsMap(const char* path) {
    std::map<dht::InfoHash, ContactShallow> result;
    std::ifstream file(path, std::ios_base::in | std::ios_base::binary);
    if (!file.is_open()) return result;
    std::vector<char> buffer((std::istreambuf_iterator<char>(file)),
                             std::istreambuf_iterator<char>());
    file.close();
    if (buffer.empty()) return result;
    try {
        msgpack::object_handle oh = msgpack::unpack(buffer.data(), buffer.size());
        oh.get().convert(result);
    } catch (const std::exception& e) {
        NSLog(@"readContactsMap: msgpack decode failed for %s: %s", path, e.what());
        result.clear();
    }
    return result;
}
}
