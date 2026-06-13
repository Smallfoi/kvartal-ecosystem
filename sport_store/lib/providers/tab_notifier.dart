import 'package:flutter/foundation.dart';

class TabNotifier extends ChangeNotifier {
  final List<int> _counts;
  int _activeTab = 0;

  TabNotifier(int tabCount) : _counts = List.filled(tabCount, 0);

  int get activeTab => _activeTab;

  int activationCount(int tabIndex) => _counts[tabIndex];

  void switchTo(int index) {
    _activeTab = index;
    _counts[index]++;
    notifyListeners();
  }
}
