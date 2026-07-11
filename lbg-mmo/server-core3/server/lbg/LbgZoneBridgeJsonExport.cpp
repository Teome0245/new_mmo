// LbgZoneBridgeJsonExport.cpp — ZB-1 export JSON atomique (20 Hz → gateway)

#include "server/lbg/LbgZoneBridgeJsonExport.h"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>

namespace lbg {
namespace zonebridge {

namespace {

std::string jsonEscape(const std::string& raw) {
    std::string out;
    out.reserve(raw.size() + 8);
    for (char c : raw) {
        if (c == '"' || c == '\\') {
            out.push_back('\\');
            out.push_back(c);
        } else if (static_cast<unsigned char>(c) >= 0x20) {
            out.push_back(c);
        }
    }
    return out;
}

std::string exportPath() {
    const char* raw = std::getenv("LBG_ZONE_BRIDGE_JSON_PATH");
    if (raw != nullptr && raw[0] != '\0') {
        return std::string(raw);
    }
    return "ia_bridge/zone_bridge_live.json";
}

bool exportEnabled() {
    const char* raw = std::getenv("LBG_ZONE_BRIDGE_JSON_EXPORT");
    if (raw == nullptr) {
        return true;
    }
    return raw[0] == '1' || raw[0] == 'y' || raw[0] == 'Y';
}

int64_t nowMs() {
    using namespace std::chrono;
    return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

std::string buildPayload(const ZoneDelta& delta) {
    const std::string zone = delta.zone_name.empty() ? "unknown" : delta.zone_name;
    std::ostringstream os;
    os << "{"
       << "\"type\":\"zone_state\","
       << "\"proto\":\"lbg-ws/2\","
       << "\"zone\":\"" << jsonEscape(zone) << "\","
       << "\"tick\":" << delta.tick << ","
       << "\"server_time_ms\":" << nowMs() << ","
       << "\"session_policy\":\"kick_other\","
       << "\"entities\":[";
    bool first = true;
    for (const auto& ent : delta.entities) {
        if (!first) {
            os << ',';
        }
        first = false;
        os << "{"
           << "\"id\":\"" << jsonEscape((ent.kind.empty() ? std::string("npc") : ent.kind) + ":" + ent.name) << "\","
           << "\"kind\":\"" << jsonEscape(ent.kind.empty() ? "npc" : ent.kind) << "\","
           << "\"name\":\"" << jsonEscape(ent.name) << "\","
           << "\"pos\":[" << ent.x << ',' << ent.y << ',' << ent.z << "],"
           << "\"source\":\"core3\""
           << "}";
    }
    os << "],\"removed_entity_ids\":[";
    first = true;
    for (uint64_t rid : delta.removed_ids) {
        if (!first) {
            os << ',';
        }
        first = false;
        os << '"' << rid << '"';
    }
    os << "],\"source\":\"zone_bridge_zb1\"}";
    return os.str();
}

void writeAtomic(const std::string& path, const std::string& payload) {
    const std::string tmp = path + ".tmp";
    {
        std::ofstream out(tmp, std::ios::trunc | std::ios::binary);
        if (!out) {
            return;
        }
        out << payload;
        out.flush();
    }
    std::rename(tmp.c_str(), path.c_str());
}

}  // namespace

void publishZoneBridgeJson(const ZoneDelta& delta) {
    if (!exportEnabled()) {
        return;
    }
    writeAtomic(exportPath(), buildPayload(delta));
}

}  // namespace zonebridge
}  // namespace lbg
