import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/services/persistence_service.dart';

class NavBarOpacityNotifier extends Notifier<double> {
  static const double defaultOpacity = 0.70;

  @override
  double build() {
    return PersistenceService.instance.loadNavBarOpacity();
  }

  Future<void> setOpacity(double value) async {
    final clamped = value.clamp(0.20, 1.0);
    state = clamped;
    await PersistenceService.instance.saveNavBarOpacity(clamped);
  }
}

final navBarOpacityProvider =
    NotifierProvider<NavBarOpacityNotifier, double>(NavBarOpacityNotifier.new);
