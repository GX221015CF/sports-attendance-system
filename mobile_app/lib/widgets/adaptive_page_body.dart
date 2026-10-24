import 'package:flutter/material.dart';

/// Keeps page actions and tablet filters available while content scrolls.
class AdaptivePageBody extends StatelessWidget {
  const AdaptivePageBody({
    super.key,
    required this.storageKey,
    required this.toolbar,
    required this.summary,
    required this.slivers,
    required this.onRefresh,
    this.filters,
    this.footer,
    this.bottomPadding = 24,
  });

  final String storageKey;
  final Widget toolbar;
  final Widget summary;
  final List<Widget> slivers;
  final Future<void> Function() onRefresh;
  final Widget? filters;
  final Widget? footer;
  final double bottomPadding;

  Widget _content({bool includeSummary = false}) => RefreshIndicator(
    onRefresh: onRefresh,
    child: CustomScrollView(
      key: PageStorageKey('$storageKey-content'),
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (includeSummary)
          SliverToBoxAdapter(
            child: Column(
              children: [
                summary,
                const SizedBox(height: 16),
                ?filters,
                const SizedBox(height: 12),
              ],
            ),
          ),
        ...slivers,
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            toolbar,
            const SizedBox(height: 8),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth >= 1000 ? 280 : 240,
                          child: ListView(
                            key: PageStorageKey('$storageKey-summary'),
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [summary],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              if (filters != null) ...[
                                filters!,
                                const SizedBox(height: 12),
                              ],
                              Expanded(child: _content()),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _content(includeSummary: true),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: footer!,
              ),
          ],
        ),
      );
    },
  );
}

/// Natural-height rows avoid fixed grid extents clipping large text and notes.
class ResponsiveSliverCards extends StatelessWidget {
  const ResponsiveSliverCards({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minCardWidth = 340,
    this.maxColumns = 2,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minCardWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns =
          ((constraints.crossAxisExtent + 12) /
                  (minCardWidth * scale.clamp(1, 1.8) + 12))
              .floor()
              .clamp(1, maxColumns);
      return SliverList.builder(
        itemCount: (itemCount / columns).ceil(),
        itemBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 12),
                Expanded(
                  child: row * columns + column < itemCount
                      ? itemBuilder(context, row * columns + column)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
