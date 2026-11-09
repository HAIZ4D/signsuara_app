import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../listen/listen_note.dart';
import '../theme/app_theme.dart';
import '../ui/widgets/gradient_button.dart';
import '../ui/widgets/motion.dart';
import 'learn_progress.dart';
import 'note_picker.dart';
import 'note_quiz.dart';
import 'quiz_question.dart';
import 'quiz_screen.dart';

const _title = 'Gemini Quiz';

/// Plays [note]'s quiz (README "Learn"): the one kept on this phone, or, when there is none (or
/// [fresh]), a new one from Gemini, after the same notice as summaries the first time.
Future<void> startNoteQuiz(BuildContext context, AppServices services, ListenNote note, {bool fresh = false}) async {
  final navigator = Navigator.of(context);
  final saved = fresh ? null : services.savedQuiz(note.id);
  if (saved != null) {
    await navigator.push(_quizRoute(services, saved));
    return;
  }
  if (!services.summaryNoticeSeen) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make a quiz with Gemini?'),
        content: const Text(
          "To make the quiz, the words heard in this note are sent to Google's Gemini. SignSuara uses "
          "Gemini's paid service, so Google does not use them to train its models.\n\n"
          'Gemini can make mistakes: if an answer looks wrong, check it against what was said.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Make quiz')),
        ],
      ),
    );
    if (ok != true) return;
    await services.markSummaryNoticeSeen(); // the same data to the same service as a summary
  }
  await navigator.push(MaterialPageRoute<void>(builder: (_) => MakeQuizScreen(services: services, note: note)));
}

/// Play again = the same questions (no new Gemini request); finishing one wins Study buddy.
MaterialPageRoute<void> _quizRoute(AppServices services, List<QuizQuestion> questions) => MaterialPageRoute(
      builder: (_) => QuizScreen(
        title: _title,
        questions: questions,
        progress: services.learn,
        again: () => questions,
        badges: const [LearnBadge.studyBuddy],
      ),
    );

/// The hub's Gemini Quiz card: pick a note, then [startNoteQuiz].
Future<void> pickNoteForQuiz(BuildContext context, AppServices services) async {
  final note = await pickNote(
    context,
    services,
    title: 'Quiz from a note',
    intro: 'Pick a note. Gemini makes questions from what was said.',
    none: 'No notes yet. Use Listen in a class or a meeting, then come back for a quiz.',
    info: (note) => services.savedQuiz(note.id) == null ? null : 'Quiz saved',
  );
  if (note != null && context.mounted) await startNoteQuiz(context, services, note);
}

/// Gemini at work on a note's quiz ("Cikgu Suara is reading your notes…"), or why it couldn't, with
/// Try again. A quiz that arrives is kept on the phone and played at once.
class MakeQuizScreen extends StatefulWidget {
  const MakeQuizScreen({super.key, required this.services, required this.note});

  final AppServices services;
  final ListenNote note;

  @override
  State<MakeQuizScreen> createState() => _MakeQuizScreenState();
}

class _MakeQuizScreenState extends State<MakeQuizScreen> {
  String? _problem;

  @override
  void initState() {
    super.initState();
    _make();
  }

  Future<void> _make() async {
    final services = widget.services;
    try {
      final maker = services.account.quizMaker;
      if (maker == null) throw const QuizFailure('Quizzes are not available: the app could not reach Firebase.');
      final questions = await maker.makeQuiz(widget.note);
      await services.saveQuiz(widget.note.id, questions);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(_quizRoute(services, questions));
    } catch (e) {
      final message = e is QuizFailure ? e.message : 'Gemini could not make the quiz. Try again in a moment.';
      if (mounted) setState(() => _problem = message);
    }
  }

  void _retry() {
    setState(() => _problem = null);
    _make();
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.xs, AppSpace.gutter, AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Leave',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: problem == null
                              ? [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: const BoxDecoration(
                                        gradient: AppGradients.sun, shape: BoxShape.circle, boxShadow: AppShadows.sunGlow),
                                    child: const Center(
                                      child: Spin(
                                        period: Duration(seconds: 3),
                                        child: Icon(Icons.auto_awesome_rounded, size: 40, color: AppColors.onYellow),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.xl),
                                  Text('Cikgu Suara is reading your notes…', textAlign: TextAlign.center, style: AppText.section),
                                  const SizedBox(height: AppSpace.s),
                                  Text(
                                    'Making ${quizLength(widget.note)} questions from "${widget.note.title}".',
                                    textAlign: TextAlign.center,
                                    style: AppText.body.copyWith(color: AppColors.inkSoft),
                                  ),
                                  const SizedBox(height: AppSpace.l),
                                  const FlowDots(color: AppColors.turq),
                                ]
                              : [
                                  const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.wrongInk),
                                  const SizedBox(height: AppSpace.m),
                                  Text(problem,
                                      textAlign: TextAlign.center, style: AppText.strong.copyWith(color: AppColors.wrongInk)),
                                  const SizedBox(height: AppSpace.xl),
                                  GradientButton(label: 'Try again', icon: Icons.refresh_rounded, onTap: _retry),
                                  const SizedBox(height: AppSpace.s),
                                  TextButton(
                                    onPressed: () => Navigator.maybePop(context),
                                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                    child: Text('Back', style: AppText.strong.copyWith(color: AppColors.turqInk)),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
