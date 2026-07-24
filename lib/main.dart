import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get_storage/get_storage.dart';

import 'core/app.dart';
import 'core/bindings/initial_binding.dart';
import 'core/utils/image_cache_config.dart';

const String _defaultStripePublishableKey =
    'pk_live_51LAbVFKHfF6NtfGFsXH3nuYXhD1sgKQnp6UE88BkyWt0cRqCpzthSiwLve4UnM7OTw4YhWSmiffTRAkpgaDOS8Hg00V8JDL67A';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  configureImageCache();

  Stripe.publishableKey = const String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: _defaultStripePublishableKey,
  );
  await Stripe.instance.applySettings();

  await GetStorage.init();
  registerRootDependencies();
  runApp(const OnlineEzzyApp());
}
