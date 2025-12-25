import 'package:flutter/widgets.dart';
import '../lifecycle_observer.dart';

class TextEditingControllerObserver
    extends LifecycleObserver<TextEditingController> {
  final String? text;

  TextEditingControllerObserver(super.state, {this.text});

  @override
  void onInit() {
    target = TextEditingController(text: text);
  }

  @override
  void onDispose() {
    target.dispose();
  }
}
