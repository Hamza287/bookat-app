import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/app_shimmer.dart';

class BusinessLogo extends StatelessWidget {
  const BusinessLogo({
    required this.logoUrl,
    required this.fallbackText,
    this.size = 52,
    super.key,
  });

  final String? logoUrl;
  final String fallbackText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final imageUrl = _imageUrl(logoUrl);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: imageUrl != null
          ? Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _LogoFallback(
                fallbackText: fallbackText,
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return AppShimmerBox(
                  width: size,
                  height: size,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                );
              },
            )
          : _LogoFallback(fallbackText: fallbackText),
    );
  }
}

class BusinessCoverImage extends StatelessWidget {
  const BusinessCoverImage({
    required this.coverUrl,
    required this.logoUrl,
    required this.fallbackText,
    this.height = 150,
    this.borderRadius,
    this.showLogoOverlay = true,
    super.key,
  });

  final String? coverUrl;
  final String? logoUrl;
  final String fallbackText;
  final double height;
  final BorderRadius? borderRadius;
  final bool showLogoOverlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final imageUrl = _imageUrl(coverUrl);
    final radius = borderRadius ??
        BorderRadius.circular(AppDimensions.radiusLarge);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _CoverFallback(
                  fallbackText: fallbackText,
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return AppShimmerBox(
                    width: double.infinity,
                    height: height,
                    borderRadius: BorderRadius.zero,
                  );
                },
              )
            else
              _CoverFallback(fallbackText: fallbackText),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colors.background.withOpacity(0.72),
                  ],
                ),
              ),
            ),
            if (showLogoOverlay)
              Positioned(
                left: AppDimensions.spacingLg,
                bottom: AppDimensions.spacingLg,
                child: BusinessLogo(
                  logoUrl: logoUrl,
                  fallbackText: fallbackText,
                  size: 56,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.fallbackText});

  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Text(
      _initial(fallbackText),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.fallbackText});

  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryLight,
            colors.surfaceMuted,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          AppMaterialIcons.business,
          color: colors.primary,
          size: 40,
        ),
      ),
    );
  }
}

String? _imageUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) {
    return raw;
  }

  final baseUri = Uri.parse(AppConfig.mediaBaseUrl);
  final origin = '${baseUri.scheme}://${baseUri.host}';
  final port = baseUri.hasPort ? ':${baseUri.port}' : '';
  final normalizedPath = raw.startsWith('/') ? raw : '/$raw';

  return '$origin$port$normalizedPath';
}

String _initial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return AppStrings.appName.substring(0, 1);
  }
  return trimmed.substring(0, 1).toUpperCase();
}
