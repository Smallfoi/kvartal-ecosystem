import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/price_text.dart';
import '../../widgets/product_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final String? heroTag;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.heroTag,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _pageController = PageController();
  int _currentImage = 0;
  String? _selectedSize;
  String? _selectedColor;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _addToCart(Product product) {
    if (_selectedSize == null) {
      _showErrorSnack('Выберите размер');
      return;
    }
    if (_selectedColor == null) {
      _showErrorSnack('Выберите цвет');
      return;
    }
    context.read<CartProvider>().add(product, _selectedSize!, _selectedColor!);
    _showAddedToCartSheet(product);
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddedToCartSheet(Product product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => _AddedToCartSheet(
        product: product,
        size: _selectedSize!,
        color: _selectedColor!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = context.watch<CatalogProvider>().getById(widget.productId);

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Товар не найден')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _ImageGallery(
                product: product,
                controller: _pageController,
                currentIndex: _currentImage,
                onPageChanged: (i) => setState(() => _currentImage = i),
                heroTag: widget.heroTag,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.brand.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey600,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 16, color: AppColors.black),
                          const SizedBox(width: 4),
                          Text(
                            '${product.rating}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${product.reviewCount} отзывов)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.grey600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PriceText(
                        price: product.price,
                        oldPrice: product.oldPrice,
                        priceStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 20),
                      _SizeSelector(
                        sizes: product.sizes,
                        selected: _selectedSize,
                        onSelected: (s) => setState(() => _selectedSize = s),
                      ),
                      const SizedBox(height: 20),
                      _ColorSelector(
                        colors: product.colors,
                        selected: _selectedColor,
                        onSelected: (c) => setState(() => _selectedColor = c),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 20),
                      const Text(
                        'ОПИСАНИЕ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.grey600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.black,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              product: product,
              onAddToCart: () => _addToCart(product),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageGallery extends StatelessWidget {
  final Product product;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final String? heroTag;

  const _ImageGallery({
    required this.product,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 440,
      pinned: true,
      backgroundColor: AppColors.white,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: AppColors.black),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: product.imageUrls.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final image = ProductImage(path: product.imageUrls[index]);
                // Hero только на первом фото — совпадает с ProductCard
                if (index == 0) {
                  return Hero(
                    tag: heroTag ?? 'product-img-${product.id}',
                    child: image,
                  );
                }
                return image;
              },
            ),
            if (product.imageUrls.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    product.imageUrls.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == currentIndex ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == currentIndex
                            ? AppColors.black
                            : AppColors.grey400,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SizeSelector extends StatelessWidget {
  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _SizeSelector({
    required this.sizes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'РАЗМЕР',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.grey600,
              ),
            ),
            if (selected != null) ...[
              const SizedBox(width: 8),
              Text(
                selected!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizes.map((size) {
            final isSelected = size == selected;
            return GestureDetector(
              onTap: () => onSelected(size),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 52,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.black : AppColors.white,
                  border: Border.all(
                    color: isSelected ? AppColors.black : AppColors.grey200,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  size,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ColorSelector extends StatelessWidget {
  final List<String> colors;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ColorSelector({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'ЦВЕТ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.grey600,
              ),
            ),
            if (selected != null) ...[
              const SizedBox(width: 8),
              Text(
                selected!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            final isSelected = color == selected;
            return GestureDetector(
              onTap: () => onSelected(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.black : AppColors.white,
                  border: Border.all(
                    color: isSelected ? AppColors.black : AppColors.grey200,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  color,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? AppColors.white : AppColors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToCart;

  const _BottomBar({required this.product, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.grey200)),
      ),
      child: Row(
        children: [
          Consumer<WishlistProvider>(
            builder: (context, wishlist, _) {
              final isFav = wishlist.contains(product.id);
              return GestureDetector(
                onTap: () => wishlist.toggle(product),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? AppColors.red : AppColors.black,
                    size: 22,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onAddToCart,
              child: const Text('ДОБАВИТЬ В КОРЗИНУ'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom sheet: товар добавлен в корзину ───────────────────────────────────

class _AddedToCartSheet extends StatelessWidget {
  final Product product;
  final String size;
  final String color;

  const _AddedToCartSheet({
    required this.product,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Заголовок
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0, 0),
                    duration: 400.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(width: 12),
              Text(
                'Добавлено в корзину',
                style: GoogleFonts.oswald(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                  letterSpacing: 0.5,
                ),
              ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Превью
          Row(
            children: [
              SizedBox(
                width: 72, height: 88,
                child: ProductImage(path: product.firstImage),
              ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideX(begin: -0.1),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppColors.grey600, letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.black, height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$size  ·  $color',
                      style: const TextStyle(fontSize: 12, color: AppColors.grey400),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${product.price.toInt()} ₽',
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 150.ms).fadeIn(duration: 300.ms).slideX(begin: 0.1),
            ],
          ),

          const SizedBox(height: 20),

          // Перейти в корзину
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              context.go('/cart');
            },
            child: Container(
              height: 52,
              color: AppColors.black,
              alignment: Alignment.center,
              child: Text(
                'ПЕРЕЙТИ В КОРЗИНУ',
                style: GoogleFonts.oswald(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.white, letterSpacing: 2,
                ),
              ),
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              'Продолжить покупки',
              style: TextStyle(
                fontSize: 14, color: AppColors.grey600,
                decoration: TextDecoration.underline,
              ),
            ),
          ).animate(delay: 260.ms).fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}
