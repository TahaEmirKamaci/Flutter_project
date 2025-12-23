import 'package:flutter/material.dart';

class CardSoundManager extends ChangeNotifier {
  double effectsVolume = 0.8;
  double musicVolume = 0.4;

  void setEffects(double v) { effectsVolume = v.clamp(0.0, 1.0); notifyListeners(); }
  void setMusic(double v) { musicVolume = v.clamp(0.0, 1.0); notifyListeners(); }

  Future<void> playDeal() async { /* hook to audioplayers */ }
  Future<void> playClick() async { /* hook to audioplayers */ }
  Future<void> playPlaceCard() async { /* hook to audioplayers */ }
  Future<void> playWin() async { /* hook to audioplayers */ }
  Future<void> playUiTransition() async { /* hook to audioplayers */ }
  Future<void> startBackground() async { /* loop music */ }
  Future<void> stopBackground() async { /* stop loop */ }
}
