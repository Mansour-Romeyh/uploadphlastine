import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';

/// روابط صفحات الويب المستخدمة في التطبيق
class AppWebUrls {
  static final Uri contact = Uri.parse(
    'https://onlineezzy.com/تواصل-معنا/?app=1',
  );

  static final Uri privacyPolicy = Uri.parse(
    'https://onlineezzy.com/سياسة-الخصوصية/?app=1',
  );

  static final Uri aboutApp = Uri.parse('https://onlineezzy.com/من-نحن/?app=1');
}

class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.title, required this.url});

  // ── Named constructors (بديل لكل stub page قديمة) ─────────────────────

  WebScreen.aboutApp({super.key})
    : title = 'حول التطبيق',
      url = AppWebUrls.aboutApp;

  WebScreen.contactUs({super.key})
    : title = 'تواصل معنا',
      url = AppWebUrls.contact;

  WebScreen.privacyPolicy({super.key})
    : title = 'سياسة الخصوصية',
      url = AppWebUrls.privacyPolicy;

  final String title;
  final Uri url;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _hasError = false;
              _progress = 10;
            });
          },
          onProgress: (value) {
            if (!mounted) return;
            final normalized = value.clamp(0, 100);
            setState(() => _progress = normalized);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _progress = 100);
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _hasError = true);
          },
        ),
      )
      ..loadRequest(widget.url);
  }

  void _reload() {
    setState(() {
      _hasError = false;
      _progress = 0;
    });
    _controller.loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final showProgress = !_hasError && _progress < 100;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            widget.title.tr,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (!_hasError)
              WebViewWidget(controller: _controller)
            else
              _buildErrorView(),
            if (showProgress)
              LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 3,
                color: const Color(0xFFE71D24),
                backgroundColor: const Color(0xFFE2E8F0),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            const Text(
              'تعذر تحميل الصفحة',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تحقق من الاتصال وحاول مرة أخرى',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _reload,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE71D24),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
