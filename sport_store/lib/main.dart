import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'data/api/api_client.dart';
import 'data/api/api_config.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/loyalty_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/loyalty_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/order_provider.dart';
import 'providers/tab_notifier.dart';
import 'providers/wishlist_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Шрифты (Inter/Oswald) встроены в assets/fonts — берём их локально, без обращения
  // к fonts.gstatic.com (офлайн + приватность §2: не шлём IP в Google). Файлы байт-в-байт
  // те же, что google_fonts скачал бы по сети, поэтому вид не меняется (D-01).
  GoogleFonts.config.allowRuntimeFetching = false;
  final prefs = await SharedPreferences.getInstance();

  // Per-service источник данных (walking skeleton): часть сервисов на реальном
  // backend, часть на mock — см. ApiConfig. Общий ApiClient хранит JWT.
  final ApiClient? api = ApiConfig.anyApi ? ApiClient() : null;
  if (api != null) {
    // JWT — в защищённом хранилище (Android Keystore / iOS Keychain), не в
    // открытых SharedPreferences (S-08). Сохраняем при смене токена, восстанавливаем
    // при старте; одноразовая миграция со старого открытого ключа prefs['jwt'].
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    api.onTokenChanged = (t) {
      if (t == null) {
        secure.delete(key: 'jwt');
      } else {
        secure.write(key: 'jwt', value: t);
      }
    };
    var token = await secure.read(key: 'jwt');
    if (token == null) {
      final legacy = prefs.getString('jwt');
      if (legacy != null && legacy.isNotEmpty) {
        await secure.write(key: 'jwt', value: legacy);
        await prefs.remove('jwt');
        token = legacy;
      }
    }
    api.authToken = token;
  }

  final ProductRepository productRepo = ApiConfig.useApiCatalog
      ? ApiProductRepository(api!)
      : MockProductRepository();
  final AuthRepository authRepo =
      ApiConfig.useApiAuth ? ApiAuthRepository(api!) : MockAuthRepository();
  final OrderRepository orderRepo =
      ApiConfig.useApiOrder ? ApiOrderRepository(api!) : MockOrderRepository();
  final LoyaltyRepository loyaltyRepo = ApiConfig.useApiLoyalty
      ? ApiLoyaltyRepository(api!)
      : MockLoyaltyRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(prefs, authRepo,
              onSessionEnd: () => api?.authToken = null),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider(prefs)),
        ChangeNotifierProvider(create: (_) => WishlistProvider(prefs)),
        ChangeNotifierProxyProvider<AuthProvider, NotificationsProvider>(
          create: (_) => NotificationsProvider(prefs,
              api: api, serverBacked: ApiConfig.useApiNotifications && api != null),
          update: (_, auth, notif) => notif!..syncAuth(auth.isLoggedIn),
        ),
        ChangeNotifierProxyProvider<AuthProvider, LoyaltyProvider>(
          create: (_) => LoyaltyProvider(prefs, loyaltyRepo,
              serverBacked: ApiConfig.useApiLoyalty),
          update: (_, auth, loyalty) {
            loyalty!.syncAuth(auth.isLoggedIn);
            return loyalty;
          },
        ),
        ChangeNotifierProvider(create: (_) => CatalogProvider(productRepo)),
        ChangeNotifierProxyProvider2<AuthProvider, NotificationsProvider,
            OrderProvider>(
          create: (_) => OrderProvider(prefs, orderRepo,
              serverBacked: ApiConfig.useApiOrder),
          update: (_, auth, notifier, order) {
            order!.attachNotifier(notifier);
            order.syncAuth(auth.isLoggedIn);
            return order;
          },
        ),
        ChangeNotifierProvider(create: (_) => TabNotifier(4)),
      ],
      child: SportStoreApp(prefs: prefs),
    ),
  );
}
