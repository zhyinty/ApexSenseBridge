#include "flydigi/SpaceStationUdp.h"

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#endif

#include <array>
#include <format>

namespace asb::flydigi {

SpaceStationUdp::~SpaceStationUdp() noexcept {
    std::string ignored;
    (void)clearAll(ignored);
}

bool SpaceStationUdp::send(const ForceTriggerCommand& command, std::string& error) const {
#ifdef _WIN32
    const unsigned side = command.side == TriggerSide::Left ? 1U : 2U;
    const auto& p = command.params;
    const auto json = std::format(
        "{{\"instructions\":[{{\"type\":1,\"parameters\":[0,{},19,{},{},{},{},{},{}]}}]}}",
        side, static_cast<unsigned>(command.mode), p[0], p[1], p[2], p[3], p[4]);
    WSADATA data{};
    if (WSAStartup(MAKEWORD(2, 2), &data) != 0) { error = "WSAStartup failed"; return false; }
    const SOCKET socket = ::socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (socket == INVALID_SOCKET) { WSACleanup(); error = "UDP socket creation failed"; return false; }
    sockaddr_in target{};
    target.sin_family = AF_INET;
    target.sin_port = htons(7878);
    target.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    const int sent = sendto(socket, json.data(), static_cast<int>(json.size()), 0,
                            reinterpret_cast<const sockaddr*>(&target), sizeof(target));
    closesocket(socket);
    WSACleanup();
    if (sent != static_cast<int>(json.size())) { error = "Space Station UDP send failed"; return false; }
    return true;
#else
    (void)command; error = "Space Station UDP is only available on Windows."; return false;
#endif
}

bool SpaceStationUdp::clearAll(std::string& error) const {
    ForceTriggerCommand left{}; left.side = TriggerSide::Left;
    ForceTriggerCommand right{}; right.side = TriggerSide::Right;
    return send(left, error) && send(right, error);
}

} // namespace asb::flydigi
