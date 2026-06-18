import 'package:flutter/material.dart';
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
  final prefs = await SharedPreferences.getInstance();

  // Per-service источник данных (walking skeleton): часть сервисов на реальном
  // backend, часть на mock — см. ApiConfig. Общий ApiClient хранит JWT.
  final ApiClient? api = ApiConfig.anyApi ? ApiClient() : null;
  if (api != null) {
    // Персист JWT: сохраняем при смене токена, восстанавливаем при старте.
    api.onTokenChanged = (t) {
      if (t == null) {
        prefs.remove('jwt');
      } else {
        prefs.setString('jwt', t);
      }
    };
    api.authToken = prefs.getString('jwt');
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
        ChangeNotifierProvider(create: (_) => NotificationsProvider(prefs)),
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
