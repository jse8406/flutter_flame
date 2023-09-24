import 'dart:async';

import 'package:doodle_jump/components/Jump_button.dart';
import 'package:doodle_jump/components/player.dart';
import 'package:doodle_jump/components/level.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/widgets.dart';

// 레벨 조정 및 해당 레벨에 맞는 배경화면, cam 랜더링

class PixelAdventure extends FlameGame with HasKeyboardHandlerComponents, DragCallbacks, HasCollisionDetection, TapCallbacks {
  //variables
  @override
  Color backgroundColor() => const Color(0xFF211F30);
  late CameraComponent cam;
  Player player = Player(char: 'Mask Dude');
  late JoystickComponent joystick;
  bool showControls = false;
  bool playSounds = false;
  double soundVolume = 1.0;
  List<String> levelNames = ['Level-01', 'Level-02'];
  int currentLevelIndex = 0;

  @override
  FutureOr<void> onLoad() async {
    // 모든 이미지를 캐시에 로드함
    await images.loadAllImages();

    _loadLevel();

    if (showControls) {
      addjoystick();
      add(JumpButton());
    }

    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (showControls) {
      updateJoystick();
    }
    super.update(dt);
  }

  void addjoystick() {
    priority = 10;
    joystick = JoystickComponent(
      knob: SpriteComponent(
        sprite: Sprite(
          images.fromCache('HUD/Knob.png'),
        ),
      ),
      background: SpriteComponent(
        sprite: Sprite(
          images.fromCache('HUD/Joystick.png'),
        ),
      ),
      margin: const EdgeInsets.only(left: 32, bottom: 32),
    );
    add(joystick);
  }

  void updateJoystick() {
    switch (joystick.direction) {
      case JoystickDirection.left:
      case JoystickDirection.upLeft:
      case JoystickDirection.downLeft:
        player.horizontalMovment = -1;
        break;
      case JoystickDirection.right:
      case JoystickDirection.upRight:
      case JoystickDirection.downRight:
        player.horizontalMovment = 1;
        break;
      default:
        player.horizontalMovment = 0;
        //idle
        break;
    }
  }

  void loadNextLevel() {
    removeWhere((component) => component is Level); //level 바뀌면 이전 레벨은 없애고 다음 레벨 add
    if (currentLevelIndex < levelNames.length - 1) {
      currentLevelIndex++;
      _loadLevel();
    } else {
      //debug용
      currentLevelIndex = 0;
      _loadLevel();
    }
  }

  void _loadLevel() {
    if (player.parent != null) {
      player.removeFromParent();
    }
    Future.delayed(const Duration(seconds: 1), () {
      Level world = Level(
        player: player,
        levelName: levelNames[currentLevelIndex],
      );
      cam = CameraComponent.withFixedResolution(
        world: world,
        width: 640,
        height: 360,
      );
      cam.viewfinder.anchor = Anchor.topLeft;

      addAll([cam, world]);
    });
  }
}
