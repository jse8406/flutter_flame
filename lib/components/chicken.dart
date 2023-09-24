import 'dart:async';
import 'dart:ui';

import 'package:doodle_jump/components/player.dart';
import 'package:doodle_jump/pixel_adventure.dart';
import 'package:flame/components.dart';

enum State { idle, run, hit }

class Chicken extends SpriteAnimationGroupComponent with HasGameRef<PixelAdventure> {
  final double offNeg;
  final double offPos;
  Chicken({
    super.position,
    super.size,
    this.offNeg = 0,
    this.offPos = 0,
  });

  static const stepTime = 0.05;
  static const tileSize = 16;
  static const runSpeed = 80;
  final textureSize = Vector2(32, 34);

  Vector2 velocity = Vector2.zero();
  double rangeNeg = 0;
  double rangePos = 0;
  double moveDirection = 1;
  double targetDirection = -1;

  late final Player player;
  late final SpriteAnimation _idleAnimation;
  late final SpriteAnimation _runAnimation;
  late final SpriteAnimation _hitAnimation;

  @override
  FutureOr<void> onLoad() {
    debugMode = true;
    player = game.player;
    _loadALlAnimation();
    _calculateRange();
    return super.onLoad();
  }

  @override
  void update(double dt) {
    _updateState();
    _movement(dt);
    super.update(dt);
  }

  void _loadALlAnimation() {
    _idleAnimation = _spriteAnimation('Idle', 13);
    _runAnimation = _spriteAnimation('Run', 14);
    _hitAnimation = _spriteAnimation('Hit', 15)..loop = false;

    animations = {
      State.idle: _idleAnimation,
      State.run: _runAnimation,
      State.hit: _hitAnimation,
    };
    current = State.idle;
  }

  SpriteAnimation _spriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
        game.images.fromCache('Enemies/Chicken/$state (32x34).png'),
        SpriteAnimationData.sequenced(
          amount: amount,
          stepTime: stepTime,
          textureSize: textureSize,
        ));
  }

  void _calculateRange() {
    rangeNeg = position.x - offNeg * tileSize;
    rangePos = position.x + offPos * tileSize;
  }

  void _movement(dt) {
    velocity.x = 0;

    double chickenOffset = (scale.x > 0) ? 0 : -width;
    double playerOffset =
        (player.scale.x > 0) ? 0 : -player.width; /*
    player가 어딜 향하든 playeroffset은 항상 player의 좌측 축을 가르킴
    원래는 flip되면 축도 돌아감
    */
    if (playerInRange()) {
      // player in chicken range
      targetDirection = (player.x + playerOffset < position.x + chickenOffset) ? -1 : 1;
      velocity.x = targetDirection * runSpeed;
      position.x += velocity.x * dt;
    }
    moveDirection = lerpDouble(moveDirection, targetDirection, 0.1) ?? 1; // ?? null이면 뒤에 값 리턴
  }

  bool playerInRange() {
    double playerOffset = (player.scale.x > 0) ? 0 : -player.width;

    return player.x + playerOffset >= rangeNeg &&
        player.x + playerOffset <= rangePos &&
        player.y + player.height > position.y &&
        player.y < position.y + height;
  }

  void _updateState() {
    current = (velocity.x != 0) ? State.run : State.idle;

    if ((moveDirection > 0 && scale.x > 0) || (moveDirection < 0 && scale.x < 0)) {
      flipHorizontallyAroundCenter();
    }
  }
}
