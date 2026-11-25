import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../app/theme.dart';
import '../core/app_exception.dart';

/// 叠在天空渐变上的半透明卡片。不用 BackdropFilter 毛玻璃：
/// 滚动列表里多个模糊层在中低端 Android 上掉帧明显，压暗填充已足够有层次。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.padding,
    this.titlePadding = EdgeInsets.zero,
  });

  final String? title;
  final IconData? icon;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// 标题行在 [padding] 之外的额外内边距：卡片内容需要贴边（如横向滚动）而标题不应贴边时使用。
  final EdgeInsetsGeometry titlePadding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Semantics(
                header: true,
                child: Padding(
                  padding: titlePadding,
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: AppColors.textTertiary),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Text(
                          title!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// 背景渐变，天气变化时平滑过渡（系统“减少动态效果”开启时直接切换）。
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, required this.colors, required this.child});

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}

/// 骨架屏占位块，带呼吸动画；“减少动态效果”时静止。
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 0.45,
        end: 0.9,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0x24FFFFFF),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// 整页错误：按错误类型给图标与文案，主按钮重试，次按钮可换地点。
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.error,
    required this.onRetry,
    this.onSecondary,
    this.secondaryLabel,
    this.contextLabel,
    this.compact = false,
  });

  final AppException error;

  /// 出错的对象（例如地点名），让用户知道是“哪个”加载失败。
  final String? contextLabel;
  final VoidCallback onRetry;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = switch (error) {
      NetworkException() => Icons.wifi_off_rounded,
      ServerException() => Icons.cloud_off_rounded,
      _ => Icons.error_outline_rounded,
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 40 : 56, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.lg),
            if (contextLabel != null) ...[
              Text(
                contextLabel!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              S.errorTitle(error),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              S.errorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(S.retry),
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, AppSpacing.minTouchTarget),
              ),
            ),
            if (onSecondary != null && secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(160, AppSpacing.minTouchTarget),
                ),
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 限制内容最大宽度并水平居中（平板、横屏）。
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
      child: child,
    ),
  );
}
