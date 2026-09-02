#pragma once

#include "core/DeviceInfo.h"
#include "core/TriggerEffect.h"

#include <array>
#include <cstddef>
#include <cstdint>

namespace asb::flydigi {

// Vendor HID command interface documented/measured by OpenFlydigi.
constexpr std::uint16_t kVendorId = 0x37D7;
constexpr std::uint16_t kVendorUsagePage = 0xFFA0;
constexpr std::uint8_t kControllerProductFamily = 0x2; // PID >> 12
// Older Flydigi controllers (including APEX 4) share this DInput identity.
// The product ID is intentionally not model-specific; command 0xEC is used
// before enabling any write path to establish the actual device type.
constexpr std::uint16_t kLegacyVendorId = 0x04B4;
constexpr std::uint16_t kLegacyProductId = 0x2412;

constexpr std::uint8_t kReportIdOut = 0x03;
constexpr std::uint8_t kReportIdIn = 0x04;
constexpr std::uint8_t kMagic0 = 0x5A;
constexpr std::uint8_t kMagic1 = 0xA5;
constexpr std::uint8_t kCmdGetInfo = 0x01;
constexpr std::uint8_t kCmdSetRumble = 0x12;
constexpr std::uint8_t kCmdSetForceTrigger = 81;
constexpr std::uint8_t kLegacyCmdGetInfo = 236;
constexpr std::uint8_t kLegacyCmdSetForceTrigger = 160;
constexpr std::size_t kReportSize = 32;

using Report = std::array<std::uint8_t, kReportSize>;

[[nodiscard]] Report buildForceTrigger(const TriggerEffect& effect, bool apply = true);
[[nodiscard]] Report buildForceTriggerRaw(const ForceTriggerCommand& command,
                                          bool apply = true);
[[nodiscard]] Report buildNormal(TriggerSide side);
[[nodiscard]] Report buildRumble(std::uint8_t lowFrequencyMotor,
                                 std::uint8_t highFrequencyMotor);
[[nodiscard]] Report buildLegacyGetInfo();
[[nodiscard]] Report buildLegacyForceTrigger(const TriggerEffect& effect,
                                              bool apply = true);
[[nodiscard]] Report buildLegacyForceTriggerRaw(const ForceTriggerCommand& command,
                                                 bool apply = true);
[[nodiscard]] bool isControllerProduct(std::uint16_t productId) noexcept;
[[nodiscard]] bool isLegacyController(const HidDeviceInfo& info) noexcept;

} // namespace asb::flydigi
