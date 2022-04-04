import 'dart:async';

import 'package:chewie/src/animated_play_pause.dart';
import 'package:chewie/src/center_play_button.dart';
import 'package:chewie/src/chewie_player.dart';
import 'package:chewie/src/chewie_progress_colors.dart';
import 'package:chewie/src/helpers/utils.dart';
import 'package:chewie/src/label_section.dart';
import 'package:chewie/src/material/material_progress_bar.dart';
import 'package:chewie/src/material/models/option_item.dart';
import 'package:chewie/src/material/widgets/options_dialog.dart';
import 'package:chewie/src/models/subtitle_model.dart';
import 'package:chewie/src/notifiers/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'widgets/playback_speed_dialog.dart';

class MaterialDesktopControls extends StatefulWidget {
  const MaterialDesktopControls({
    this.showPlayButton = true,
    Key? key,
  }) : super(key: key);

  final bool showPlayButton;

  @override
  State<StatefulWidget> createState() {
    return _MaterialDesktopControlsState();
  }
}

class _MaterialDesktopControlsState extends State<MaterialDesktopControls>
    with SingleTickerProviderStateMixin {
  late PlayerNotifier notifier;
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  late var _subtitlesPosition = Duration.zero;
  bool _subtitleOn = false;
  Timer? _showAfterExpandCollapseTimer;
  bool _dragging = false;
  bool _displayTapped = false;

  final barHeight = 48.0 * 1.5;
  final marginSize = 5.0;

  late VideoPlayerController controller;
  ChewieController? _chewieController;

  // Yummy Custom
  Timer timerStep = Timer(const Duration(milliseconds: 500), () {});
  bool isSelect = false;
  bool isPlay = false;
  int positionVideo = 0;

  // We know that _chewieController is set in didChangeDependencies
  ChewieController get chewieController => _chewieController!;

  @override
  void initState() {
    super.initState();
    notifier = Provider.of<PlayerNotifier>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
            context,
            chewieController.videoPlayerController.value.errorDescription!,
          ) ??
          const Center(
            child: Icon(
              Icons.error,
              color: Colors.white,
              size: 42,
            ),
          );
    }

    return MouseRegion(
      onHover: (_) {
        _cancelAndRestartTimer();
      },
      child: GestureDetector(
        onTap: () => _cancelAndRestartTimer(),
        child: AbsorbPointer(
          absorbing: notifier.hideStuff,
          child: Stack(
            children: [
              if (_latestValue.isBuffering)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                _buildAreaStep(),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  // if (_subtitleOn)
                  //   Transform.translate(
                  //     offset: Offset(
                  //         0.0, notifier.hideStuff ? barHeight * 0.8 : 0.0),
                  //     child:
                  //         _buildSubtitles(context, chewieController.subtitle!),
                  //   ),
                  // _buildAreaStep(),
                  if (isPlay)
                    const SizedBox.shrink()
                  else
                    _buildLabelRecipeCarousel(),
                  if (notifier.hideStuff)
                    const SizedBox.shrink()
                  else
                    _buildBottomBar(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    if (_oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildOptionsButton({
    IconData? icon,
    bool isPadded = false,
  }) {
    final options = <OptionItem>[
      OptionItem(
        onTap: () async {
          Navigator.pop(context);
          _onSpeedButtonTap();
        },
        iconData: Icons.speed,
        title: chewieController.optionsTranslation?.playbackSpeedButtonText ??
            'Playback speed',
      )
    ];

    if (chewieController.subtitle != null &&
        chewieController.subtitle!.isNotEmpty) {
      options.add(
        OptionItem(
          onTap: () {
            _onSubtitleTap();
            Navigator.pop(context);
          },
          iconData: _subtitleOn
              ? Icons.closed_caption
              : Icons.closed_caption_off_outlined,
          title: chewieController.optionsTranslation?.subtitlesButtonText ??
              'Subtitles',
        ),
      );
    }

    if (chewieController.additionalOptions != null &&
        chewieController.additionalOptions!(context).isNotEmpty) {
      options.addAll(chewieController.additionalOptions!(context));
    }

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: IconButton(
        padding: isPadded ? const EdgeInsets.all(8.0) : EdgeInsets.zero,
        onPressed: () async {
          _hideTimer?.cancel();

          if (chewieController.optionsBuilder != null) {
            await chewieController.optionsBuilder!(context, options);
          } else {
            await showModalBottomSheet<OptionItem>(
              context: context,
              isScrollControlled: true,
              useRootNavigator: chewieController.useRootNavigator,
              builder: (context) => OptionsDialog(
                options: options,
                cancelButtonText:
                    chewieController.optionsTranslation?.cancelButtonText,
              ),
            );
          }

          if (_latestValue.isPlaying) {
            _startHideTimer();
          }
        },
        icon: Icon(
          icon ?? Icons.more_vert,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSubtitles(BuildContext context, Subtitles subtitles) {
    if (!_subtitleOn) {
      return Container();
    }
    final currentSubtitle = subtitles.getByPosition(_subtitlesPosition);
    if (currentSubtitle.isEmpty) {
      return Container();
    }

    if (chewieController.subtitleBuilder != null) {
      return chewieController.subtitleBuilder!(
        context,
        currentSubtitle.first!.text,
      );
    }

    return Padding(
      padding: EdgeInsets.all(marginSize),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0x96000000),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          currentSubtitle.first!.text.toString(),
          style: const TextStyle(
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  AnimatedOpacity _buildBottomBar(
    BuildContext context,
  ) {
    final iconColor = Theme.of(context).textTheme.button!.color;

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: barHeight + (chewieController.isFullScreen ? 20.0 : 0),
        padding:
            EdgeInsets.only(bottom: chewieController.isFullScreen ? 10.0 : 15),
        child: SafeArea(
          bottom: chewieController.isFullScreen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            verticalDirection: VerticalDirection.up,
            children: [
              Flexible(
                child: Row(
                  children: <Widget>[
                    _buildPlayPause(controller),
                    if (chewieController.isLive)
                      const Expanded(child: Text('LIVE'))
                    else
                      _buildPosition(iconColor),
                    const Spacer(),
                    _buildMuteButton(controller),
                    if (chewieController.allowFullScreen) _buildExpandButton(),
                  ],
                ),
              ),
              if (!chewieController.isLive)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.only(
                      right: 20,
                      left: 20,
                      bottom: chewieController.isFullScreen ? 5.0 : 0,
                    ),
                    child: Row(
                      children: [
                        _buildProgressBar(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  GestureDetector _buildExpandButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight + (chewieController.isFullScreen ? 15.0 : 0),
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
          ),
          child: Center(
            child: Icon(
              chewieController.isFullScreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    final bool isFinished = _latestValue.position >= _latestValue.duration;
    final bool showPlayButton =
        widget.showPlayButton && !_dragging && !notifier.hideStuff;

    return GestureDetector(
      onTap: () {
        if (_latestValue.isPlaying) {
          if (_displayTapped) {
            setState(() {
              notifier.hideStuff = true;
            });
          } else {
            _cancelAndRestartTimer();
          }
        } else {
          _playPause();

          setState(() {
            notifier.hideStuff = true;
          });
        }
      },
      child: CenterPlayButton(
        backgroundColor: Colors.black54,
        iconColor: Colors.white,
        isFinished: isFinished,
        isPlaying: controller.value.isPlaying,
        show: showPlayButton,
        onPressed: _playPause,
        isFullscreen: chewieController.isFullScreen,
        onExpandCollapse: _onExpandCollapse,
      ),
    );
  }

  Future<void> _onSpeedButtonTap() async {
    _hideTimer?.cancel();

    final chosenSpeed = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: chewieController.useRootNavigator,
      builder: (context) => PlaybackSpeedDialog(
        speeds: chewieController.playbackSpeeds,
        selected: _latestValue.playbackSpeed,
      ),
    );

    if (chosenSpeed != null) {
      controller.setPlaybackSpeed(chosenSpeed);
    }

    if (_latestValue.isPlaying) {
      _startHideTimer();
    }
  }

  GestureDetector _buildMuteButton(
    VideoPlayerController controller,
  ) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();

        if (_latestValue.volume == 0) {
          controller.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller.value.volume;
          controller.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: ClipRect(
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.only(
              right: 15.0,
            ),
            child: Icon(
              _latestValue.volume > 0 ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildPlayPause(VideoPlayerController controller) {
    return GestureDetector(
      onTap: _playPause,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        margin: const EdgeInsets.only(left: 8.0, right: 4.0),
        padding: const EdgeInsets.only(
          left: 12.0,
          right: 12.0,
        ),
        child: AnimatedPlayPause(
          playing: controller.value.isPlaying,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPosition(Color? iconColor) {
    final position = _latestValue.position;
    final duration = _latestValue.duration;

    return Text(
      '${formatDuration(position)} / ${formatDuration(duration)}',
      style: const TextStyle(
        fontSize: 14.0,
        color: Colors.white,
      ),
    );
  }

  void _onSubtitleTap() {
    setState(() {
      _subtitleOn = !_subtitleOn;
    });
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      notifier.hideStuff = false;
      _displayTapped = true;
    });
  }

  Future<void> _initialize() async {
    _subtitleOn = chewieController.subtitle?.isNotEmpty ?? false;
    controller.addListener(_updateState);

    _updateState();

    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }

    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        setState(() {
          notifier.hideStuff = false;
        });
      });
    }
  }

  void _onExpandCollapse() {
    setState(() {
      notifier.hideStuff = true;

      chewieController.toggleFullScreen();
      _showAfterExpandCollapseTimer =
          Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _cancelAndRestartTimer();
        });
      });
    });
  }

  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration;

    setState(() {
      if (controller.value.isPlaying) {
        notifier.hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
      } else {
        _cancelAndRestartTimer();

        if (!controller.value.isInitialized) {
          controller.initialize().then((_) {
            controller.play();
          });
        } else {
          if (isFinished) {
            controller.seekTo(Duration.zero);
          }
          controller.play();
        }
      }
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        notifier.hideStuff = true;
      });
    });
  }

  void _updateState() {
    if (!mounted) return;
    setState(() {
      _latestValue = controller.value;
      _subtitlesPosition = controller.value.position;
    });
    videoPlayerListener();
  }

  void videoPlayerListener() {
    final bool isPlaying = _latestValue.isPlaying;
    final position = _latestValue.position;
    final duration = _latestValue.duration;
    positionVideo = position.inSeconds;
    if (isPlaying) {
      isPlay = true;
    } else {
      isPlay = false;
    }

    if (!isPlay && position == duration) {
      controller.seekTo(Duration.zero).then((v) {
        controller.pause();
      });
    }
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: MaterialVideoProgressBar(
        controller,
        onDragStart: () {
          setState(() {
            _dragging = true;
          });

          _hideTimer?.cancel();
        },
        onDragEnd: () {
          setState(() {
            _dragging = false;
          });

          _startHideTimer();
        },
        colors: chewieController.materialProgressColors ??
            ChewieProgressColors(
              playedColor: Theme.of(context).colorScheme.secondary,
              handleColor: Theme.of(context).colorScheme.secondary,
              bufferedColor: Theme.of(context).backgroundColor.withOpacity(0.5),
              backgroundColor: Theme.of(context).disabledColor.withOpacity(.5),
            ),
      ),
    );
  }

  void onRequestStep(int index) {
    if (isPlay) {
      setState(() {
        isSelect = true;
        timerStep.cancel();
        if (chewieController.cookingStep[index] != null) {
          controller
              .seekTo(
            Duration(
              milliseconds:
                  ((chewieController.cookingStep[index].startAt as int) *
                          1000) +
                      300,
            ),
          )
              .then((a) {
            timerStep = Timer(const Duration(milliseconds: 400), () {
              _chewieController?.activeCook = index;
              isSelect = false;
            });
            if (chewieController.cookingStep[index] != null) {
              _chewieController?.stepCook =
                  chewieController.cookingStep[index].text as String;
            }
          });
        }
      });
    } else {
      if (chewieController.cookingStep[index] != null) {
        controller.seekTo(
          Duration(
            milliseconds:
                (chewieController.cookingStep[index].startAt as int) * 1000,
          ),
        );
        _chewieController?.activeCook = index;
        _chewieController?.stepCook =
            chewieController.cookingStep[index].text as String;
      }
    }

    chewieController.onCookingStepChange
        .call(chewieController.cookingStep[index]);
  }

  Color _selectStep(int index) {
    final idx = index + 1;
    if (chewieController.cookingStep[index] != null &&
        idx >= chewieController.cookingStep.length &&
        !isSelect &&
        positionVideo >=
            (int.tryParse(
                    chewieController.cookingStep[index].startAt.toString()) ??
                0)) {
      _chewieController?.activeCook = index;
      _chewieController?.stepCook =
          chewieController.cookingStep[index].text as String;
      return Colors.white;
    } else if (!isSelect && idx < chewieController.cookingStep.length) {
      if (chewieController.cookingStep[index] != null) {
        if (positionVideo >=
                (int.tryParse(
                      chewieController.cookingStep[index].startAt.toString(),
                    ) ??
                    0) &&
            positionVideo <
                (int.tryParse(
                        chewieController.cookingStep[idx].startAt.toString()) ??
                    0)) {
          _chewieController?.activeCook = index;
          _chewieController?.stepCook =
              chewieController.cookingStep[index].text as String;

          return Colors.white;
        }
      }
    }

    return Colors.white.withOpacity(0.2);
  }

  Widget _buildAreaStep() {
    return Container(
      color: Colors.grey.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (chewieController.isFullScreen && chewieController.isOfficial)
            Container(
              width: (MediaQuery.of(context).size.width -
                      MediaQuery.of(context).size.height) /
                  2,
              padding: const EdgeInsets.only(top: 20),
              child: ListView.builder(
                physics: const ClampingScrollPhysics(),
                shrinkWrap: true,
                itemCount: chewieController.cookingStep.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        onRequestStep(index);
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(
                        bottom: 20,
                        left: 20,
                        right: 20,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectStep(index),
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: controller.value.size.width / 82.2 * 2,
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.fitHeight,
                          child: Text(
                            chewieController.cookingStep[index] != null
                                ? chewieController.cookingStep[index].title
                                    as String
                                : '',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(),
          _buildHitArea(),
          if (chewieController.isFullScreen && chewieController.isOfficial)
            Container(
              width: (MediaQuery.of(context).size.width -
                      MediaQuery.of(context).size.height) /
                  2,
              height: MediaQuery.of(context).size.height,
              padding: const EdgeInsets.only(
                  top: 10, left: 10, bottom: 10, right: 10),
              alignment: Alignment.center,
              child: ListView(
                physics: const ClampingScrollPhysics(),
                shrinkWrap: true,
                children: <Widget>[
                  Text(
                    chewieController.stepCook == ""
                        ? ""
                        : chewieController.stepCook,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          else
            Container(),
        ],
      ),
    );
  }

  Widget _buildLabelRecipeCarousel() {
    return chewieController.modelLabelRecipe.isNotEmpty
        ? LabelSection(
            section: chewieController.modelLabelRecipe,
            baseCDNUrl: chewieController.baseCDNUrl,
          )
        : const SizedBox.shrink();
  }
}
