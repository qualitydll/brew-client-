import 'link_parser.dart';

const kMainGroup = 'PROXY';
const kAutoGroup = 'AUTO';
const kTestUrl = 'https://www.gstatic.com/generate_204';

class CoreOptions {
  const CoreOptions({
    required this.mixedPort,
    required this.apiPort,
    required this.secret,
    required this.mode,
    required this.tun,
    required this.allowLan,
    this.externalTun = false,
    this.userRules = const [],
  });

  final int mixedPort;
  final int apiPort;
  final String secret;
  final String mode;
  final bool tun;
  final bool allowLan;
  final bool externalTun;
  final List<String> userRules;
}

const _privateRules = [
  'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve',
  'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
  'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve',
  'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
  'IP-CIDR,100.64.0.0/10,DIRECT,no-resolve',
  'DOMAIN-SUFFIX,local,DIRECT',
  'DOMAIN-SUFFIX,lan,DIRECT',
];

/// Builds a minimal but complete config around a list of share-link proxies.
Map<String, dynamic> configFromProxies(List<Map<String, dynamic>> proxies) {
  final names = [for (final p in proxies) p['name'] as String];
  return {
    'proxies': proxies,
    'proxy-groups': [
      {
        'name': kMainGroup,
        'type': 'select',
        'proxies': [kAutoGroup, ...names, 'DIRECT'],
      },
      {
        'name': kAutoGroup,
        'type': 'url-test',
        'proxies': names,
        'url': kTestUrl,
        'interval': 300,
        'tolerance': 50,
        'lazy': true,
      },
    ],
    'rules': [..._privateRules, 'MATCH,$kMainGroup'],
  };
}

Map<String, dynamic> baseConfigFor(ParsedSubscription sub) {
  if (sub.clashConfig != null) {
    return Map<String, dynamic>.from(sub.clashConfig!);
  }
  return configFromProxies(sub.proxies);
}

/// Overrides the parts of the config the launcher owns (ports, API, TUN, DNS).
Map<String, dynamic> applyCoreOptions(
  Map<String, dynamic> base,
  CoreOptions o,
) {
  final cfg = Map<String, dynamic>.from(base);
  for (final key in [
    'port',
    'socks-port',
    'redir-port',
    'tproxy-port',
    'external-ui',
    'external-controller-tls',
  ]) {
    cfg.remove(key);
  }
  cfg['mixed-port'] = o.mixedPort;
  cfg['allow-lan'] = o.allowLan;
  cfg['bind-address'] = '*';
  cfg['mode'] = o.mode;
  cfg['log-level'] = 'info';
  cfg['ipv6'] = cfg['ipv6'] ?? true;
  cfg['external-controller'] = '127.0.0.1:${o.apiPort}';
  cfg['secret'] = o.secret;
  cfg['unified-delay'] = true;
  cfg['tcp-concurrent'] = true;
  cfg['find-process-mode'] = 'off';
  cfg['profile'] = {'store-selected': true, 'store-fake-ip': true};

  if (o.userRules.isNotEmpty) {
    // Mihomo uses first-match semantics, so custom rules take precedence.
    final providerRules = cfg['rules'];
    cfg['rules'] = [
      ...o.userRules,
      if (providerRules is List) ...providerRules,
    ];
  }

  if (o.tun) {
    cfg['tun'] = {
      'enable': true,
      'stack': 'mixed',
      'auto-route': true,
      'auto-redirect': false,
      'auto-detect-interface': true,
      'strict-route': true,
      'dns-hijack': ['any:53', 'tcp://any:53'],
    };
  } else {
    cfg['tun'] = {'enable': false};
  }

  if (o.tun || o.externalTun) {
    final dns = cfg['dns'];
    if (dns is! Map || dns['enable'] != true) {
      cfg['dns'] = {
        'enable': true,
        'ipv6': true,
        'enhanced-mode': 'fake-ip',
        'fake-ip-range': '198.18.0.1/16',
        'fake-ip-filter': [
          '*.lan',
          '*.local',
          'localhost.ptlogin2.qq.com',
          '+.msftconnecttest.com',
          '+.msftncsi.com',
        ],
        'default-nameserver': ['1.1.1.1', '8.8.8.8'],
        'nameserver': [
          'https://1.1.1.1/dns-query',
          'https://dns.google/dns-query',
        ],
      };
    }
  }
  return cfg;
}
