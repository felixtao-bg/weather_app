import 'package:flutter/material.dart';

import '../../app/dependencies.dart';
import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../domain/location.dart';
import '../../ui/common_widgets.dart';
import 'location_search_controller.dart';

/// 地点搜索页。选中后 `pop` 返回 [Location]，自身不知道天气页的存在（低耦合）。
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  /// 用 MaterialPageRoute：转场由主题决定（iOS 侧滑返回 / Android 预测性返回）。
  static Route<Location> route() => MaterialPageRoute<Location>(
    builder: (_) => const SearchScreen(),
    settings: const RouteSettings(name: '/search'),
  );

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final LocationSearchController _controller;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Controller 生命周期 = 页面生命周期：返回时 dispose，取消防抖并丢弃在途请求。
    final deps = AppScope.read(context);
    _controller = LocationSearchController(
      geocoding: deps.geocoding,
      store: deps.locationStore,
      languageCode: deps.languageCode,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _select(Location location) => Navigator.of(context).pop(location);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final state = _controller.state;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      // BackButton 自动使用平台图标（iOS ‹ / Android ←）。
                      const BackButton(),
                      Expanded(child: _buildField(state)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 2,
                  child: state.status == SearchStatus.loading
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null,
                ),
                Expanded(child: _buildBody(state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildField(SearchState state) {
    return TextField(
      controller: _textController,
      autofocus: true,
      autocorrect: false,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.search,
      onChanged: _controller.onQueryChanged,
      onSubmitted: (_) => _controller.submit(),
      style: const TextStyle(fontSize: 17),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        hintText: S.searchHint,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
        suffixIcon: ListenableBuilder(
          listenable: _textController,
          builder: (context, _) => _textController.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: S.clearSearch,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _textController.clear();
                    _controller.onQueryChanged('');
                  },
                ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBody(SearchState state) {
    switch (state.status) {
      case SearchStatus.idle:
        if (state.recents.isEmpty) {
          return const _Message(icon: Icons.travel_explore_rounded, title: S.searchIdleHint);
        }
        return _LocationList(
          header: S.recent,
          onClear: _controller.clearRecents,
          locations: state.recents,
          leadingIcon: Icons.history_rounded,
          onSelect: _select,
        );
      case SearchStatus.loading when state.results.isEmpty:
        return const _ResultsSkeleton();
      case SearchStatus.loading:
      case SearchStatus.results:
        return AnimatedOpacity(
          // 新结果未到时淡化旧结果，提示“正在更新”，但不清空导致跳动。
          opacity: state.status == SearchStatus.loading ? 0.55 : 1,
          duration: const Duration(milliseconds: 150),
          child: _LocationList(locations: state.results, query: state.query, onSelect: _select),
        );
      case SearchStatus.empty:
        return _Message(
          icon: Icons.search_off_rounded,
          title: S.noResults(state.query),
          body: S.noResultsHint,
        );
      case SearchStatus.error:
        return SingleChildScrollView(
          child: ErrorPanel(error: state.error!, onRetry: _controller.retry, compact: true),
        );
    }
  }
}

class _LocationList extends StatelessWidget {
  const _LocationList({
    required this.locations,
    required this.onSelect,
    this.query,
    this.header,
    this.onClear,
    this.leadingIcon,
  });

  final List<Location> locations;
  final ValueChanged<Location> onSelect;
  final String? query;
  final String? header;
  final VoidCallback? onClear;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final subtitles = disambiguatedSubtitles(locations);
    final hasHeader = header != null;
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: locations.length + (hasHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.sm, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      header!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, AppSpacing.minTouchTarget),
                    ),
                    child: const Text(S.clear),
                  ),
              ],
            ),
          );
        }
        final i = hasHeader ? index - 1 : index;
        return _LocationTile(
          location: locations[i],
          subtitle: subtitles[i],
          query: query,
          leadingIcon: leadingIcon,
          onTap: () => onSelect(locations[i]),
        );
      },
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.subtitle,
    required this.onTap,
    this.query,
    this.leadingIcon,
  });

  final Location location;
  final String subtitle;
  final VoidCallback onTap;
  final String? query;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final flag = location.flagEmoji;
    return Semantics(
      button: true,
      label: [location.name, if (subtitle.isNotEmpty) subtitle].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                  child: leadingIcon != null
                      ? Icon(leadingIcon, size: 20, color: AppColors.textSecondary)
                      : flag != null
                      ? Text(flag, style: const TextStyle(fontSize: 20))
                      : const Icon(Icons.place_outlined, size: 20),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightedName(name: location.name, query: query),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 把名称中与查询词匹配的部分高亮，帮助用户快速确认是不是想要的结果。
class _HighlightedName extends StatelessWidget {
  const _HighlightedName({required this.name, this.query});

  final String name;
  final String? query;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500);
    final q = query?.toLowerCase();
    final start = q == null || q.isEmpty ? -1 : name.toLowerCase().indexOf(q);
    if (start < 0) {
      return Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    final end = start + q!.length;
    return Text.rich(
      TextSpan(
        style: base.copyWith(color: AppColors.textSecondary),
        children: [
          TextSpan(text: name.substring(0, start)),
          TextSpan(
            text: name.substring(start, end),
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: name.substring(end)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 56, AppSpacing.xxl, AppSpacing.xl),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.4, color: AppColors.textSecondary),
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.searching,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                child: Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, radius: 20),
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 140, height: 16),
                          SizedBox(height: AppSpacing.sm),
                          SkeletonBox(width: 200, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
