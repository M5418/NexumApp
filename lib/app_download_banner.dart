import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'responsive/responsive_breakpoints.dart';

/// Hook this into MaterialApp.builder:
///   builder: appDownloadBannerBuilder,
Widget appDownloadBannerBuilder(BuildContext context, Widget? child) {
  return AppDownloadBannerInjector(child: child);
}

class AppDownloadBannerInjector extends StatefulWidget {
  const AppDownloadBannerInjector({super.key, required this.child});
  final Widget? child;

  @override
  State<AppDownloadBannerInjector> createState() => _AppDownloadBannerInjectorState();
}

class _AppDownloadBannerInjectorState extends State<AppDownloadBannerInjector> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final showBanner = shouldShowDownloadBanner(context) && !_dismissed;

    return Stack(
      children: [
        widget.child ?? const SizedBox.shrink(),
        if (kIsWeb && showBanner)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _BannerCard(
                  onClose: () => setState(() => _dismissed = true),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.phone_iphone, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome to Nexum!",
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "For the best experience on your phone or tablet, get our free app from the App Store or Google Play.",
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StoreButton(store: _Store.apple, onPressed: () {
                          // UI only (no-op). Hook url_launcher later if desired.
                        }),
                        _StoreButton(store: _Store.google, onPressed: () {
                          // UI only (no-op). Hook url_launcher later if desired.
                        }),
                        _ContinueWebButton(onClose: onClose),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Dismiss",
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Store { apple, google }

class _StoreButton extends StatelessWidget {
  const _StoreButton({required this.store, required this.onPressed});
  final _Store store;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isApple = store == _Store.apple;
    final bg = isApple ? Colors.black : const Color(0xFF1A73E8);
    final text = isApple ? "App Store" : "Google Play";

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isApple ? Icons.apple : Icons.android, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                "Get it on $text",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueWebButton extends StatelessWidget {
  const _ContinueWebButton({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onClose,
      child: const Text("Continue on web"),
    );
  }
}