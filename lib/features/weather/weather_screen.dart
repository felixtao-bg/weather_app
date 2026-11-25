import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/dependencies.dart';
import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../domain/location.dart';
import '../../domain/weather_condition.dart';
import '../../ui/common_widgets.dart';
import '../../ui/formatters.dart';
import '../../ui/weather_glyph.dart';
import '../search/search_screen.dart';
import 'popular_places.dart';
import 'weather_controller.dart';
import 'widgets/current_conditions.dart';
import 'widgets/daily_forecast_card.dart';
import 'widgets/details_grid.dart';
import 'widgets/hourly_forecast_card.dart';

/// 首页。只负责“把 [WeatherState] 映射成界面”和转发用户意图，不含业务逻辑。
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key, required this.controller});

  final WeatherController controller;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late final AppLifecycleListener _lifecycle;

  // 每分钟重建一次，让“当地时间”和逐小时列表的起点保持正确。
  Timer? _minuteTicker;

  /// 下拉刷新时 RefreshIndicator 已有转圈，不再叠加顶部进度条。
  bool _pullRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 类似 iOS 的 sceneWillEnterForeground：回到前台时让 Controller 判断是否需要刷新。
    _lifecycle = AppLifecycleListener(onResume: () => widget.controller.onAppResumed());
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _openSearch() async {
    final picked = await Navigator.of(context).push<Location>(SearchScreen.route());
    if (picked == null || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(widget.controller.selectLocation(picked));
  }

  Future<void> _pullToRefresh() async {
    setState(() => _pullRefreshing = true);
    await widget.controller.refresh();
    if (mounted) setState(() => _pullRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final current = state.snapshot?.forecast.current;
        final sky = current == null
            ? neutralSky
            : skyGradient(current.condition.kind, isDay: current.isDay);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: sky.last,
            body: SkyBackground(
              colors: sky,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _TopBar(
                      onSearch: _openSearch,
                      showProgress: state.isLoading && state.hasData && !_pullRefreshing,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        child: _buildBody(state, deps.clock()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(WeatherState state, DateTime now) {
    final location = state.location;
    final snapshot = state.snapshot;

    if (location == null) {
      return _EmptyState(
        key: const ValueKey('empty'),
        onSearch: _openSearch,
        onPick: (l) => widget.controller.selectLocation(l),
      );
    }
    if (snapshot == null && state.error != null) {
      return SingleChildScrollView(
        key: const ValueKey('error'),
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.only(top: 72),
            child: ErrorPanel(
              error: state.error!,
              contextLabel: location.name,
              onRetry: widget.controller.refresh,
              onSecondary: _openSearch,
              secondaryLabel: S.chooseAnother,
            ),
          ),
        ),
      );
    }
    if (snapshot == null) {
      return const _LoadingSkeleton(key: ValueKey('loading'));
    }

    final forecast = snapshot.forecast;
    final localNow = forecast.localNow(now);
    final fetchedAgo = Fmt.ago(snapshot.fetchedAt, now);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      key: ValueKey('data-${location.id}'),
      onRefresh: _pullToRefresh,
      color: AppColors.background,
      backgroundColor: Colors.white,
      child: CustomScrollView(
        // 内容不足一屏时也允许下拉刷新。
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ContentWidth(
              child: CurrentConditions(location: location, forecast: forecast, now: now),
            ),
          ),
          if (state.error != null)
            SliverToBoxAdapter(
              child: ContentWidth(
                child: _StaleBanner(
                  message: S.staleBanner(fetchedAgo),
                  onRetry: widget.controller.refresh,
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl + bottomInset,
            ),
            sliver: SliverToBoxAdapter(
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HourlyForecastCard(hours: forecast.upcomingHours(now)),
                    const SizedBox(height: AppSpacing.md),
                    DailyForecastCard(
                      days: forecast.upcomingDays(now),
                      localToday: localNow,
                      currentTemperature: forecast.current.temperature,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DetailsGrid(current: forecast.current, today: forecast.today(now)),
                    const SizedBox(height: AppSpacing.xl),
                    _Footer(updated: S.updatedAgo(fetchedAgo)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSearch, required this.showProgress});

  final VoidCallback onSearch;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.sm, 0),
          child: Row(
            children: [
              Semantics(
                header: true,
                child: const Text(
                  S.appTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onSearch,
                tooltip: S.searchTooltip,
                icon: const Icon(Icons.search_rounded, size: 26),
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(AppSpacing.minTouchTarget),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 2,
          child: showProgress ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
      ],
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: const Color(0x40000000),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: const Color(0x55FFB4A9)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13.5))),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(64, AppSpacing.minTouchTarget),
              ),
              child: const Text(S.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.updated});

  final String updated;

  static final _openMeteo = Uri.parse('https://open-meteo.com/');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(updated, style: const TextStyle(fontSize: 12.5, color: AppColors.textTertiary)),
        // 署名是 CC BY 4.0 的硬性要求；可点击跳转数据源。
        TextButton(
          onPressed: () => launchUrl(_openMeteo, mode: LaunchMode.externalApplication),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            minimumSize: const Size(0, AppSpacing.minTouchTarget),
            textStyle: const TextStyle(fontSize: 12.5, decoration: TextDecoration.underline),
          ),
          child: const Text(S.attribution),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.onSearch, required this.onPick});

  final VoidCallback onSearch;
  final ValueChanged<Location> onPick;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: WeatherGlyph(condition: WeatherCondition.partlyCloudy, isDay: true, size: 112),
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: const Text(
                S.emptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.3),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              S.emptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.5, height: 1.45, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            // 外观像搜索框的按钮：点击进入独立搜索页（键盘、返回手势都更自然）。
            Semantics(
              button: true,
              label: S.emptyCta,
              excludeSemantics: true,
              child: Material(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: InkWell(
                  onTap: onSearch,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 54),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppColors.textSecondary),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              S.emptyCta,
                              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              S.popular.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final place in popularPlaces)
                  ActionChip(
                    avatar: ExcludeSemantics(child: Text(place.flagEmoji ?? '')),
                    label: Text(place.name),
                    onPressed: () => onPick(place),
                    backgroundColor: const Color(0x1FFFFFFF),
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.loadingWeather,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            ContentWidth(
              child: Column(
                children: [
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 180, height: 30),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 140, height: 16),
                  SizedBox(height: AppSpacing.xl),
                  SkeletonBox(width: 200, height: 96, radius: 24),
                  SizedBox(height: AppSpacing.md),
                  SkeletonBox(width: 160, height: 20),
                  SizedBox(height: AppSpacing.xxl),
                  SkeletonBox(height: 150, radius: AppRadius.card),
                  SizedBox(height: AppSpacing.md),
                  SkeletonBox(height: 320, radius: AppRadius.card),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
