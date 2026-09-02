#pragma once

#include "core/TriggerEffect.h"

#include <string>

namespace asb::flydigi {

// Flydigi Space Station's local adapter protocol (127.0.0.1:7878).
class SpaceStationUdp {
public:
    ~SpaceStationUdp() noexcept;
    [[nodiscard]] bool send(const ForceTriggerCommand& command, std::string& error) const;
    [[nodiscard]] bool clearAll(std::string& error) const;
};

} // namespace asb::flydigi
