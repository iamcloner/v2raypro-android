# Changelog

## [1.3.2] - 2026-10-18

- **WebSocket & ECH Connectivity**: Fixed WebSocket stream settings, enforced HTTP/1.1 ALPN, and removed invalid early data injections.
- **Accurate Real-Delay Calibration**: Prioritized Cloudflare generate_204 with 1-RTT warm keep-alive testing matching v2rayN and v2rayNG standards.
- **VPN IPv4 Routing Fix**: Reverted dual-stack IPv6 blackholing to ensure reliable internet connectivity across all network types.
- **Domestic Bridge Exit Resolution**: Correctly resolves real exit countries for domestic reverse-proxy and clean IP nodes.

## [1.2.2] - 2026-10-17

- **Accurate Real-Delay Ping**: Calibrated 1-RTT HTTP probe matching v2rayNG; bypassed VPN tunnel; fixed WebSocket and xhttp latency testing.
- **Background Session Restoration**: Correctly restores connection status, duration, outbound IP, ping, and traffic when reopening app from background / Recent Apps.
- **Localized Notifications**: Status bar notification displays the active config name and adapts to the selected app language.
- **Seamless Config Switch**: Smooth handover between proxy nodes without unexpected VPN disconnection.
