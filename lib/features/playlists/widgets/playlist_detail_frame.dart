import 'package:flutter/material.dart';

import '../../../shared/widgets/content_width.dart';
import 'edit_decorations.dart';
import 'edit_foot_frame.dart';
import 'edit_header_app_bar.dart';

/// The edit page's frame — flat ground, the sticky cloud-and-temple header,
/// lotus corners at the foot — so a set's pages read as one.
class PlaylistDetailFrame extends StatelessWidget {
  const PlaylistDetailFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.slivers,
    this.actions = const [],
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> slivers;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: editGround(Theme.of(context)),
      bottomNavigationBar: footer == null
          ? null
          : EditFootFrame(child: footer!),
      body: LayoutBuilder(
        builder: (context, box) {
          // A list of prayers, so it takes the list pages' column; only the
          // set editor and the share pages are phone-wide compositions.
          final gutter = ((box.maxWidth - ContentWidth.gridWidth) / 2).clamp(
            0.0,
            double.infinity,
          );
          return CustomScrollView(
            slivers: [
              EditHeaderAppBar(
                title: title,
                subtitle: subtitle,
                actions: actions,
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16 + gutter, 12, 16 + gutter, 28),
                sliver: SliverMainAxisGroup(slivers: slivers),
              ),
            ],
          );
        },
      ),
    );
  }
}
