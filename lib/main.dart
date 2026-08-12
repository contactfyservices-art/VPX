import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AntiDetectApp());
}

class AntiDetectApp extends StatelessWidget {
  const AntiDetectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anti-Detect Browser',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: const BrowserScreen(),
    );
  }
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? webViewController;
  ProxyController? proxyController;

  double _progress = 0;

  final List<Map<String, String>> proxyList = [
    {
      'name': 'Connexion Directe (Sans Proxy)',
      'host': '',
      'port': '',
    },
    {
      'name': 'Proxy Personnalisé 1',
      'host': '127.0.0.1',
      'port': '8080',
    },
  ];

  late Map<String, String> selectedProxy;

  final TextEditingController urlController = TextEditingController(
    text: 'https://pixelscan.net',
  );

  // Script d'injection complet pour neutraliser la détection d'empreinte
  final String antiFingerprintScript = '''
    (function() {
      // 1. Masquage de la présence d'automatisation (WebDriver)
      Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined,
      });

      // 2. Spoofing Matériel et Navigateur
      Object.defineProperty(navigator, 'hardwareConcurrency', {
        get: () => 8
      });

      Object.defineProperty(navigator, 'deviceMemory', {
        get: () => 8
      });

      Object.defineProperty(navigator, 'platform', {
        get: () => 'Win32'
      });

      Object.defineProperty(navigator, 'language', {
        get: () => 'en-US'
      });

      Object.defineProperty(navigator, 'languages', {
        get: () => ['en-US', 'en']
      });

      // 3. Spoofing Canvas Fingerprinting
      const originalGetContext =
          HTMLCanvasElement.prototype.getContext;

      HTMLCanvasElement.prototype.getContext = function(type, flags) {
        const context =
            originalGetContext.apply(this, arguments);

        if (type === '2d' && context) {
          const originalGetImageData =
              context.getImageData;

          context.getImageData = function(x, y, w, h) {
            const imageData =
                originalGetImageData.apply(this, arguments);

            for (
              let i = 0;
              i < imageData.data.length;
              i += 4
            ) {
              imageData.data[i] =
                  imageData.data[i] ^ ((i % 13) + 1);
            }

            return imageData;
          };
        }

        return context;
      };

      // 4. Spoofing WebGL (GPU / Vendeur)
      const getParameter =
          WebGLRenderingContext.prototype.getParameter;

      WebGLRenderingContext.prototype.getParameter =
          function(parameter) {
        if (parameter === 37445) {
          return 'Google Inc. (NVIDIA)';
        }

        if (parameter === 37446) {
          return 'ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0)';
        }

        return getParameter.apply(this, arguments);
      };

      // 5. Blocage complet des fuites WebRTC
      delete window.RTCPeerConnection;
      delete window.RTCSessionDescription;
      delete window.RTCIceCandidate;

      // 6. Protection contre l'Audio Fingerprinting
      if (window.AudioContext ||
          window.webkitAudioContext) {

        const AudioContext =
            window.AudioContext ||
            window.webkitAudioContext;

        const originalGetChannelData =
            AudioBuffer.prototype.getChannelData;

        AudioBuffer.prototype.getChannelData =
            function() {
          const results =
              originalGetChannelData.apply(this, arguments);

          for (let i = 0; i < results.length; i += 100) {
            results[i] = results[i] + 0.0000001;
          }

          return results;
        };
      }
    })();
  ''';

  @override
  void initState() {
    super.initState();

    selectedProxy = proxyList.first;

    _initializeProxy();
  }

  Future<void> _initializeProxy() async {
    // CORRECTION : isFeatureSupported() retourne Future<bool>
    if (!await WebViewFeature.isFeatureSupported(
      WebViewFeature.PROXY_OVERRIDE,
    )) {
      return;
    }

    proxyController = ProxyController.instance();

    if (selectedProxy['host']!.isEmpty) {
      await proxyController!.clearProxyOverride();
    } else {
      await proxyController!.setProxyOverride(
        settings: ProxySettings(
          proxyRules: [
            ProxyRule(
              url:
                  '${selectedProxy['host']}:${selectedProxy['port']}',
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Anti-Detect Browser',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DropdownButton<Map<String, String>>(
              value: selectedProxy,
              dropdownColor: const Color(0xFF2C2C2C),
              underline: const SizedBox(),
              icon: const Icon(
                Icons.shield_outlined,
                color: Colors.greenAccent,
              ),
              items: proxyList.map((proxy) {
                return DropdownMenuItem<Map<String, String>>(
                  value: proxy,
                  child: Text(
                    proxy['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedProxy = value;
                  });

                  _applyProxyAndReload();
                }
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    webViewController?.reload();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: urlController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Entrez une URL...',
                      hintStyle:
                          const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (value) {
                      _loadUrl(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward,
                    color: Colors.greenAccent,
                  ),
                  onPressed: () {
                    _loadUrl(urlController.text);
                  },
                ),
              ],
            ),
          ),

          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              color: Colors.greenAccent,
              minHeight: 2,
            ),

          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://pixelscan.net'),
              ),

              initialSettings: InAppWebViewSettings(
                userAgent:
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                    'AppleWebKit/537.36 '
                    '(KHTML, like Gecko) '
                    'Chrome/124.0.0.0 '
                    'Safari/537.36',
                javaScriptEnabled: true,
                transparentBackground: true,
              ),

              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: antiFingerprintScript,
                  injectionTime:
                      UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),

              onWebViewCreated: (controller) {
                webViewController = controller;
              },

              onProgressChanged: (controller, progress) {
                if (!mounted) return;

                setState(() {
                  _progress = progress / 100;
                });
              },

              onLoadStop: (controller, url) {
                if (url != null && mounted) {
                  urlController.text = url.toString();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _loadUrl(String urlString) {
    if (urlString.trim().isEmpty) {
      return;
    }

    Uri url = Uri.parse(urlString.trim());

    if (!url.scheme.startsWith('http')) {
      url = Uri.parse('https://$urlString');
    }

    webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(url.toString()),
      ),
    );
  }

  Future<void> _applyProxyAndReload() async {
    // CORRECTION : isFeatureSupported() retourne Future<bool>
    if (!await WebViewFeature.isFeatureSupported(
      WebViewFeature.PROXY_OVERRIDE,
    )) {
      return;
    }

    proxyController ??= ProxyController.instance();

    if (selectedProxy['host']!.isEmpty) {
      await proxyController!.clearProxyOverride();
    } else {
      await proxyController!.setProxyOverride(
        settings: ProxySettings(
          proxyRules: [
            ProxyRule(
              url:
                  '${selectedProxy['host']}:${selectedProxy['port']}',
            ),
          ],
        ),
      );
    }

    await webViewController?.reload();
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }
}
