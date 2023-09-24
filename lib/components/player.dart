import 'dart:async';

import 'package:doodle_jump/components/checkpoint.dart';
import 'package:doodle_jump/components/collision_block.dart';
import 'package:doodle_jump/components/fruit.dart';
import 'package:doodle_jump/components/custom_hitbox.dart';
import 'package:doodle_jump/components/saw.dart';
import 'package:doodle_jump/components/utils.dart';
import 'package:doodle_jump/pixel_adventure.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

// 플레이어 애니메이션 및 위치 관리

enum PlayerState { idle, running, jumping, falling, hit, appearing, disappearing } //열거형 타입, 연관된 상수를 모아놓은 집합

class Player extends SpriteAnimationGroupComponent with HasGameRef<PixelAdventure>, KeyboardHandler, CollisionCallbacks {
  String char;
  Player({position, this.char = 'Mask Dude'}) : super(position: position);

  late final SpriteAnimation idleAnimation; // const vs final: 값을 결정하는 시점의 차이 const는 컴파일 단계에서, final은 그 값이 결정되는 실행 시점에서
  late final SpriteAnimation runningAnimation;
  late final SpriteAnimation jumpingAnimation;
  late final SpriteAnimation fallingAnimation;
  late final SpriteAnimation hitAnimation;
  late final SpriteAnimation appearingAnimation;
  late final SpriteAnimation disappearingAnimation;

  final double stepTime = 0.05;

  final double _gravity = 30;
  final double _jumpForce = 460;
  final double _terminalVelocity = 260; // 한계 속도
  double horizontalMovment = 0;
  double moveSpeed = 120;
  Vector2 startingPos = Vector2.zero();
  Vector2 velocity = Vector2.zero();
  bool isOnground = false;
  bool hasJumped = false;
  bool gotHit = false;
  bool reachedCheckpoint = false;
  List<CollisionBlock> collisionBlocks = [];
  Customhitbox hitbox = Customhitbox(
    offsetX: 10,
    offsetY: 4,
    width: 14,
    height: 28,
  );
  double fixedDeltaTIme = 1 / 60;
  double accumulatedTime = 0;

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (!reachedCheckpoint) {
      if (other is Fruit) other.collidedWithPlayer();
      if (other is Saw) _respawn();
      if (other is Checkpoint) _reachedCheckpoint();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();
    startingPos = Vector2(position.x, position.y);
    add(RectangleHitbox(
      position: Vector2(hitbox.offsetX, hitbox.offsetY),
      size: Vector2(hitbox.width, hitbox.height),
    ));
    return super.onLoad();
  }

  @override
  void update(double dt) {
    accumulatedTime += dt;

    while (accumulatedTime >= fixedDeltaTIme) {
      // 이 순서도 중요하다 applygravity 랑 checkvertical 함수 바뀌니까 버그 생김
      if (!gotHit && !reachedCheckpoint) {
        _updatePlayerState();
        _updatePlayerMovement(fixedDeltaTIme);
        _checkHorizontalCollisions();
        _applyGravity(fixedDeltaTIme);
        _checkVerticalCollisions();
      }
      accumulatedTime -= fixedDeltaTIme;
    }
    super.update(dt);
  }

  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    horizontalMovment = 0;
    final isLeftKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyA) || keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final isRightKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyD) || keysPressed.contains(LogicalKeyboardKey.arrowRight);

    horizontalMovment += isLeftKeyPressed ? -1 : 0;
    horizontalMovment += isRightKeyPressed ? 1 : 0;

    hasJumped = keysPressed.contains(LogicalKeyboardKey.space);
    return super.onKeyEvent(event, keysPressed);
  }

  SpriteAnimation _spriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$char/$state (32x32).png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2.all(32),
      ),
    );
  }

  SpriteAnimation _specialSpriteAnimation(String state, int amount) {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache('Main Characters/$state (96x96).png'),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2.all(96),
        loop: false,
      ),
    );
  }

  void _loadAllAnimations() {
    idleAnimation = _spriteAnimation('Idle', 11);
    runningAnimation = _spriteAnimation('Run', 12);
    jumpingAnimation = _spriteAnimation('Jump', 1);
    fallingAnimation = _spriteAnimation('Fall', 1);
    hitAnimation = _spriteAnimation('Hit', 7)..loop = false;
    appearingAnimation = _specialSpriteAnimation('Appearing', 7);
    disappearingAnimation = _specialSpriteAnimation('Disappearing', 7);

    animations = {
      PlayerState.idle: idleAnimation,
      PlayerState.running: runningAnimation,
      PlayerState.jumping: jumpingAnimation,
      PlayerState.falling: fallingAnimation,
      PlayerState.hit: hitAnimation,
      PlayerState.appearing: appearingAnimation,
      PlayerState.disappearing: disappearingAnimation,
    };
    current = PlayerState.idle;
  }

  void _updatePlayerMovement(double dt) {
    if (hasJumped && isOnground) {
      _playerJump(dt);
    }
    velocity.x = horizontalMovment * moveSpeed;
    position.x += velocity.x * dt;
  }

  void _updatePlayerState() {
    PlayerState playerState = PlayerState.idle;
    if (velocity.x < 0 && scale.x > 0) {
      // 왼쪽으로 가는데 오른쪽을 보고있던 상태면 flip 왼쪽 보고있는데 왼쪽으로 간다고 또 뒤집으면 안되니깐
      flipHorizontallyAroundCenter();
    } else if (velocity.x > 00 && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }

    if (velocity.x != 0) {
      playerState = PlayerState.running;
    }
    if (velocity.y > 0) playerState = PlayerState.falling;
    if (velocity.y < 0) playerState = PlayerState.jumping;
    current = playerState;
  }

  void _checkHorizontalCollisions() {
    for (final block in collisionBlocks) {
      if (!block.isPlatform) {
        if (checkCollision(this, block)) {
          if (velocity.x > 0) {
            velocity.x = 0;
            position.x = block.x - hitbox.offsetX - hitbox.width;
            break;
          } else if (velocity.x < 0) {
            velocity.x = 0;
            position.x = block.x + block.width + hitbox.width + hitbox.offsetX;
            break;
          }
        }
      }
    }
  }

  void _playerJump(double dt) {
    if (game.playSounds) FlameAudio.play('jump.wav', volume: game.soundVolume);
    velocity.y = -_jumpForce;
    position.y += velocity.y * dt;
    isOnground = false;
    hasJumped = false;
  }

  void _applyGravity(double dt) {
    velocity.y += _gravity;
    velocity.y = velocity.y.clamp(-_jumpForce, _terminalVelocity);
    position.y += velocity.y * dt;
  }

  void _checkVerticalCollisions() {
    for (final block in collisionBlocks) {
      if (block.isPlatform) {
        if (checkCollision(this, block)) {
          if (velocity.y > 0) {
            velocity.y = 0;
            position.y = block.y - hitbox.height - hitbox.offsetY;
            isOnground = true;
            break;
          }
        }
      } else {
        if (checkCollision(this, block)) {
          if (velocity.y > 0) {
            velocity.y = 0;
            position.y = block.y - hitbox.height - hitbox.offsetY;
            isOnground = true;
            break;
          } else if (velocity.y < 0) {
            velocity.y = 0;
            position.y = block.y + block.height - hitbox.offsetY;
            break;
          }
        }
      }
    }
  }

  void _respawn() async {
    if (game.playSounds) FlameAudio.play('hit.wav', volume: game.soundVolume);
    const canMoveduration = Duration(milliseconds: 300);
    gotHit = true;
    current = PlayerState.hit;

    await animationTicker?.completed;
    animationTicker?.reset();

    scale.x = 1;
    position = startingPos - Vector2.all(32);
    current = PlayerState.appearing;

    await animationTicker?.completed;
    animationTicker?.reset();

    velocity = Vector2.zero();
    position = startingPos;
    _updatePlayerState();
    Future.delayed(canMoveduration, () => gotHit = false);
  }

  void _reachedCheckpoint() async {
    reachedCheckpoint = true;
    if (game.playSounds) FlameAudio.play('disappear.wav', volume: game.soundVolume);
    if (scale.x > 0) {
      position = position - Vector2.all(32);
    } else if (scale.x < 0) {
      position = position + Vector2(32, -32);
    }
    current = PlayerState.disappearing;
    await animationTicker?.completed;
    animationTicker?.reset();
    removeFromParent();
    const reachedCheckpointDuration = Duration(milliseconds: 100);
    Future.delayed(reachedCheckpointDuration, () {
      reachedCheckpoint = false;
      game.loadNextLevel();
    });
  }
}
