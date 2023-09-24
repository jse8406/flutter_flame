import 'package:doodle_jump/pixel_adventure.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //앱 바인딩 초기화 -> UI rendering 가능
  await Flame.device.fullScreen();
  await Flame.device.setLandscape(); //화면 축 전환(가로) 

  PixelAdventure game = PixelAdventure();
  runApp(GameWidget(game: game));
}

