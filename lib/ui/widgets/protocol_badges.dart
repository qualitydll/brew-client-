import 'package:flutter/material.dart';

/// Compact protocol/transport labels derived only from the node's real config.
class ProtocolBadges extends StatelessWidget {
  const ProtocolBadges({
    super.key,
    required this.type,
    required this.config,
    required this.foreground,
  });

  final String type;
  final Map<String, dynamic> config;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final tags = <_ProtocolTag>[];
    final normalized = type.toLowerCase();
    final base = switch (normalized) {
      'vless' => const _ProtocolTag('VLESS', Color(0xFF514B48), Color(0xFFE5E0DD)),
      'vmess' => const _ProtocolTag('VMess', Color(0xFF244B3A), Color(0xFFA5E6C1)),
      'trojan' => const _ProtocolTag('Trojan', Color(0xFF44305F), Color(0xFFD6B9FF)),
      'ss' || 'shadowsocks' => const _ProtocolTag('Shadowsocks', Color(0xFF5A3D20), Color(0xFFFFD0A0)),
      'hysteria2' || 'hysteria' => const _ProtocolTag('Hysteria', Color(0xFF174A49), Color(0xFF9DE7DE)),
      'tuic' => const _ProtocolTag('TUIC', Color(0xFF193D64), Color(0xFF82B9FF)),
      'shadowquic' => const _ProtocolTag('ShadowQUIC', Color(0xFF612D36), Color(0xFFFF9DAA)),
      'anytls' => const _ProtocolTag('AnyTLS', Color(0xFF3B4657), Color(0xFFC7D9F4)),
      _ => _ProtocolTag(type.isEmpty ? 'Proxy' : type, const Color(0xFF484848), const Color(0xFFE0E0E0)),
    };
    tags.add(base);

    final network = (config['network']?.toString() ??
            (config.containsKey('xhttp-opts') ? 'xhttp' : ''))
        .toLowerCase();
    if (network == 'xhttp') {
      tags.add(const _ProtocolTag('XHTTP', Color(0xFF5B431F), Color(0xFFFFD166)));
    } else if (network == 'grpc') {
      tags.add(const _ProtocolTag('gRPC', Color(0xFF4B3B19), Color(0xFFFFD166)));
    } else if (network == 'ws') {
      tags.add(const _ProtocolTag('WS', Color(0xFF34404A), Color(0xFFB8D9F2)));
    } else if (network == 'h2' || network == 'http') {
      tags.add(const _ProtocolTag('HTTP/2', Color(0xFF34404A), Color(0xFFB8D9F2)));
    }

    final reality = config['reality-opts'];
    if (reality is Map && reality.isNotEmpty) {
      tags.add(const _ProtocolTag('REALITY', Color(0xFF193D64), Color(0xFF82B9FF)));
    }

    final encryption = config['encryption']?.toString().toLowerCase() ?? '';
    if (encryption.contains('mlkem') ||
        encryption.contains('post-quantum') ||
        encryption == 'pq') {
      tags.add(const _ProtocolTag('PQ', Color(0xFF612D36), Color(0xFFFF9DAA)));
    }

    final obfsValue = config['obfs'];
    final obfs = obfsValue is Map
        ? (obfsValue['type']?.toString().toLowerCase() ?? '')
        : obfsValue?.toString().toLowerCase() ?? '';
    if (obfs == 'gecko') {
      tags.add(const _ProtocolTag('Gecko', Color(0xFF5B431F), Color(0xFFFFD166)));
    } else if (obfs == 'salamander') {
      tags.add(const _ProtocolTag('Salamander', Color(0xFF3B4657), Color(0xFFC7D9F4)));
    }

    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: [
        for (final tag in tags.take(4))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tag.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tag.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: tag.foreground,
                  ),
            ),
          ),
      ],
    );
  }
}

class _ProtocolTag {
  const _ProtocolTag(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}
