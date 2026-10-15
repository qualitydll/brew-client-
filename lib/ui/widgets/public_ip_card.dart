import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'common.dart';

class PublicIpCard extends StatefulWidget {
  const PublicIpCard({super.key});

  @override
  State<PublicIpCard> createState() => _PublicIpCardState();
}

class _PublicIpCardState extends State<PublicIpCard> {
  String? _ip;
  String? _country;
  String? _countryCode;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  String _flag(String? code) {
    if (code == null || code.length != 2) return '🌐';
    return String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => c + 127397));
  }

  Future<Map<String, dynamic>?> _getJson(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {'Accept': 'application/json', 'User-Agent': 'Brew-VPN'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    String? ip;
    String? country;
    String? code;
    // Use independent public endpoints so one unavailable service does not
    // make the widget fail completely.
    final results = await Future.wait([
      _getJson('https://ipwho.is/'),
      _getJson('https://ipapi.co/json/'),
      _getJson('https://api.ipify.org?format=json'),
    ]);

    for (final data in results) {
      if (data == null) continue;
      final candidate = (data['ip'] ?? data['query'])?.toString();
      if (ip == null && candidate != null && candidate.isNotEmpty) ip = candidate;
      final candidateCountry = (data['country'] ?? data['country_name'])?.toString();
      if (country == null && candidateCountry != null && candidateCountry.isNotEmpty) {
        country = candidateCountry;
      }
      final candidateCode = (data['country_code'] ?? data['country_code2'])?.toString();
      if (code == null && candidateCode != null && candidateCode.length == 2) {
        code = candidateCode;
      }
    }

    if (!mounted) return;
    setState(() {
      _ip = ip;
      _country = country;
      _countryCode = code;
      _error = ip == null ? 'Не удалось получить публичный IP' : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Публичный IP', style: textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                )),
              ),
              IconButton(
                tooltip: 'Проверить IP ещё раз',
                onPressed: _loading ? null : _refresh,
                icon: AnimatedRotation(
                  turns: _loading ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: const Icon(Icons.refresh_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _loading && _ip == null
                ? const LinearProgressIndicator(key: ValueKey('loading'))
                : Column(
                    key: ValueKey('${_ip ?? _error}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ip ?? _error ?? 'Проверяем…',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: _ip == null ? scheme.onSurfaceVariant : scheme.onSurface,
                        ),
                      ),
                      if (_ip != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(_flag(_countryCode), style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              _country ?? 'Страна не определена',
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            )),
                            if (_loading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Проверяется через несколько публичных сервисов',
            style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
