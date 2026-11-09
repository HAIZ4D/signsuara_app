import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../signer/sign_player.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/gradient_button.dart';
import 'learn_ui.dart';
import 'note_signs.dart';
import 'quiz_question.dart';
import 'quiz_screen.dart';
import 'sign_quest_screen.dart';
import 'teka_isyarat.dart';

/// A lesson (README "Learn"): the avatar shows signs one by one, each with its gloss and English
/// (and, from a note, the sentence it was heard in). Then a quiz on just these signs, and Sign Quest
/// for the ones the glove knows. Used by the units of the path and by "Learn the signs you heard".
class SignLessonScreen extends StatefulWidget {
  const SignLessonScreen({
    super.key,
    required this.services,
    required this.title,
    required this.subtitle,
    required this.ids,
    this.heard = const {},
    this.onWatchedAll,
    this.onQuizDone,
    this.openClip = openAssetClip,
  });

  final AppServices services;
  final String title; // "Kenali Diri", "Signs from your note"
  final String subtitle; // "Unit 1", the note's title
  final List<String> ids; // clip ids, in teaching order
  final Map<String, HeardSign> heard; // where each was heard (a note's lesson)
  final VoidCallback? onWatchedAll; // the last sign was reached
  final String? Function(int right, int total)? onQuizDone; // see QuizScreen.onFinished
  final ClipOpener openClip;

  @override
  State<SignLessonScreen> createState() => _SignLessonScreenState();
}

class _SignLessonScreenState extends State<SignLessonScreen> {
  late final _player = SignPlayer(open: widget.openClip);
  var _at = 0;

  AppServices get _services => widget.services;
  List<String> get _ids => widget.ids;

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _show() {
    _player.play(clipsToShow(_services.signer.library, _ids[_at]));
    if (_at + 1 == _ids.length) {
      // after this frame: telling (e.g. a unit's stars) redraws other screens, not allowed mid-build
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onWatchedAll?.call());
    }
  }

  void _go(int to) {
    setState(() => _at = to);
    _show();
  }

  void _quiz() {
    List<QuizQuestion>? round() => tekaIsyaratRound(_services.signer.library, only: _ids, length: min(10, _ids.length));
    final questions = round();
    if (questions == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => QuizScreen(
        title: widget.title,
        questions: questions,
        progress: _services.learn,
        timed: true,
        openClip: widget.openClip,
        again: round,
        onFinished: widget.onQuizDone,
      ),
    ));
  }

  void _practise(List<String> gloveSigns) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SignQuestScreen(
          services: _services,
          signs: ([...gloveSigns]..shuffle()).take(5).toList(),
          openClip: widget.openClip,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final total = _ids.length;
    final last = _at + 1 == total;
    final gloveSigns = gloveSignsAmong(_ids);
    final back = _at > 0 ? [Expanded(child: _BackButton(onTap: () => _go(_at - 1))), const SizedBox(width: 10)] : const <Widget>[];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xs, AppSpace.gutter, AppSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  IconButton(
                    tooltip: 'Leave the lesson',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.section),
                        Text('Sign ${_at + 1} of $total · ${widget.subtitle}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                ]),
                ProgressDots(total: total, results: List.filled(_at, true), at: _at),
                const SizedBox(height: AppSpace.m),
                Expanded(
                  child: LearnStage(player: _player, actions: [
                    StageButton(icon: Icons.replay_rounded, label: 'Sign it again', onTap: _player.replay),
                    StageButton(
                      icon: Icons.slow_motion_video_rounded,
                      label: 'Slower signing',
                      selected: _player.speed < 1,
                      onTap: () => setState(() => _player.speed = _player.speed < 1 ? 1 : 0.5),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpace.m),
                _SignCard(id: _ids[_at], heard: widget.heard[_ids[_at]]),
                const SizedBox(height: AppSpace.m),
                if (!last)
                  Row(children: [
                    ...back,
                    Expanded(
                      flex: 2,
                      child: GradientButton(label: 'Next sign', icon: Icons.arrow_forward_rounded, onTap: () => _go(_at + 1)),
                    ),
                  ])
                else ...[
                  GradientButton(label: 'Quiz me on these', icon: Icons.quiz_rounded, onTap: _quiz),
                  if (back.isNotEmpty || gloveSigns.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s),
                    Row(children: [
                      ...back,
                      if (gloveSigns.isNotEmpty)
                        Expanded(
                          flex: 2,
                          child: GradientButton(
                            label: 'Practise with the glove',
                            icon: Icons.back_hand_rounded,
                            gradient: AppGradients.blueTile,
                            shadow: AppShadows.blueTile,
                            onTap: () => _practise(gloveSigns),
                          ),
                        ),
                    ]),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The sign now shown: its gloss and English; from a note also how often it was heard and the
/// sentence it was heard in, with its words marked.
class _SignCard extends StatelessWidget {
  const _SignCard({required this.id, this.heard});

  final String id;
  final HeardSign? heard;

  @override
  Widget build(BuildContext context) {
    final name = signAnswer(id);
    final heard = this.heard;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.l, 14, AppSpace.l, 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), boxShadow: AppShadows.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.text,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.heroTitle.copyWith(color: AppColors.ink, fontSize: 24)),
                  if (name.detail case final english?)
                    Text(english, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: AppColors.inkSoft)),
                ],
              ),
            ),
            if (heard != null) ...[
              const SizedBox(width: AppSpace.s),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.turqWash, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(heard.times == 1 ? 'Heard once' : 'Heard ${heard.times}×',
                    style: AppText.small.copyWith(color: AppColors.turqInk)),
              ),
            ],
          ]),
          if (heard != null) ...[
            const SizedBox(height: AppSpace.s),
            Text('HEARD IN', style: AppText.eyebrow.copyWith(color: AppColors.inkSoft, fontSize: 10.5)),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                style: AppText.body.copyWith(color: AppColors.ink),
                children: [
                  TextSpan(text: '“${heard.line.substring(0, heard.start)}'),
                  TextSpan(
                    text: heard.line.substring(heard.start, heard.end),
                    style: const TextStyle(color: AppColors.onYellow, backgroundColor: AppColors.yellow, fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: '${heard.line.substring(heard.end)}”'),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.5),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
}
