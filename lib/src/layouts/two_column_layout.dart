import 'package:moonrelay/src/layouts/custom_scaffold.dart';
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
    return CustomScaffold(
      content: Row(
        children: [
          Container(
            decoration: const BoxDecoration(),
            clipBehavior: Clip.antiAlias,
            width: 420,
            child: mainView,
          ),
          const Divider(
            direction: Axis.vertical,
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
