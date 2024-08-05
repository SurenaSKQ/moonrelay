import 'package:fluent_ui/fluent_ui.dart';

class TwoColumnLayout extends StatelessWidget {
  final Widget mainView;
  final Widget sideView;

  const TwoColumnLayout({
    super.key,
    required this.mainView,
    required this.sideView,
  });
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Row(
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(),
            width: 420,
            child: mainView,
          ),
          Container(
            width: 5.0,
            decoration: FluentTheme.of(context).dividerTheme.decoration,
          ),
          Expanded(
            child: ClipRRect(
              child: sideView,
            ),
          ),
        ],
      ),
    );
  }
}
