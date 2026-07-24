import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayPalApprovalPage extends StatefulWidget {
  const PayPalApprovalPage({
    super.key,
    required this.approvalUrl,
    this.returnBaseUrl = 'https://onlineezzy.com/paypal-return',
  });

  final String approvalUrl;
  final String returnBaseUrl;

  @override
  State<PayPalApprovalPage> createState() => _PayPalApprovalPageState();
}

class _PayPalApprovalPageState extends State<PayPalApprovalPage> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith(widget.returnBaseUrl)) {
              final uri = Uri.tryParse(url);
              final token = uri?.queryParameters['token'];
              Navigator.of(context).pop(token);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  @override
  Widget build(BuildContext context) {
    final showProgress = _progress < 100;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تأكيد PayPal'), centerTitle: true),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
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
}
