import 'package:flutter/widgets.dart';

final class ScrollableScreen extends StatelessWidget {
  const ScrollableScreen({
    super.key,
    required this.maxWidth,
    required this.mainChild,
    this.bottomChild,
  });

  final Widget mainChild;
  final Widget? bottomChild;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: mainChild,
                        ),
                      ),
                    ),
                  ),
                  if (bottomChild case final child)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // SliverMainAxisGroup(
            //   slivers: [
            //     SliverToBoxAdapter(
            //       child: Center(
            //         child: ConstrainedBox(
            //           constraints: BoxConstraints(maxWidth: maxWidth),
            //           child: Padding(
            //             padding: const EdgeInsets.all(24.0),
            //             child: mainChild,
            //           ),
            //         ),
            //       ),
            //     ),
            //     if (bottomChild case final child)
            //       SliverFillRemaining(
            //         hasScrollBody: false,
            //         child: Padding(
            //           padding: const EdgeInsets.all(24.0),
            //           child: Align(
            //             alignment: Alignment.bottomCenter,
            //             child: child,
            //           ),
            //         ),
            //       ),
            //   ],
            // ),
          ],
        );
      },
    );
  }
}
