import 'package:flutter/material.dart';

import '../learn/note_quiz.dart';
import '../listen/listen_note.dart';
import '../listen/note_summary.dart';
import '../theme/app_theme.dart';
import '../ui/time_label.dart';
import '../ui/widgets/gradient_button.dart';
import '../ui/widgets/motion.dart';
import '../ui/widgets/notice.dart';

/// The "Gemini notes" side of a note (README "Listen and Notes"): the Summarise card, Gemini at
/// work, or Gemini's notes as cards to read, tick off and copy from.
class NoteNotesView extends StatelessWidget {
  const NoteNotesView({
    super.key,
    required this.note,
    required this.busy,
    required this.problem,
    required this.onSummarize,
    required this.onAgain,
    required this.onToggle,
    required this.onCopy,
    required this.onSeeSaid,
    required this.quizSaved,
    required this.onQuiz,
    required this.onNewQuiz,
    this.signsHeard = const [],
    this.onLearnSigns,
  });

  final ListenNote note;
  final bool busy; // Gemini is writing
  final String? problem;
  final VoidCallback onSummarize;
  final VoidCallback onAgain;
  final ValueChanged<int> onToggle; // ticks or unticks an action
  final ValueChanged<String> onCopy; // an important detail
  final VoidCallback onSeeSaid;
  final bool quizSaved; // a Gemini quiz of this note is kept on the phone (Learn)
  final VoidCallback onQuiz; // play it, or make one
  final VoidCallback onNewQuiz;
  final List<String> signsHeard; // glosses of the signs heard in the note that the avatar can show
  final VoidCallback? onLearnSigns;

  @override
  Widget build(BuildContext context) {
    final summary = note.summary;
    final quiz = [
      ('quiz', _QuizMe(note: note, saved: quizSaved, onQuiz: onQuiz, onNewQuiz: onNewQuiz)),
      if (signsHeard.isNotEmpty && onLearnSigns != null) ('signs', _SignsHeard(glosses: signsHeard, onLearn: onLearnSigns!)),
    ];
    final cards = <(String, Widget)>[
      if (problem case final problem?) ('problem', Notice(message: problem)),
      if (busy)
        ('writing', const _Writing())
      else if (summary == null) ...[
        ('ask', _AskGemini(onTap: onSummarize)),
        ...quiz,
      ] else ...[
        ('overview', _Overview(summary: summary, onAgain: onAgain)),
        ...quiz,
        if (summary.keyPoints.isNotEmpty) ('points', _KeyPoints(points: summary.keyPoints)),
        if (summary.actions.isNotEmpty) ('todo', _ToDo(actions: summary.actions, done: summary.done, onToggle: onToggle)),
        if (summary.details.isNotEmpty) ('details', _Details(details: summary.details, onCopy: onCopy)),
        if (summary.terms.isNotEmpty) ('words', _Words(terms: summary.terms)),
        ('check', _CheckAgainst(onSeeSaid: onSeeSaid)),
      ],
    ];
    // New cards rise in one after another (Gemini's answer arriving); a tick changes nothing here.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (id, card)) in cards.indexed)
          FadeUp(
            key: ValueKey(id),
            delay: Duration(milliseconds: 60 * i.clamp(0, 5)),
            child: Padding(padding: const EdgeInsets.only(bottom: 14), child: card),
          ),
      ],
    );
  }
}

/// No notes yet: what Gemini would make, and the button. Its edge slowly turns, like the Listen stage.
class _AskGemini extends StatelessWidget {
  const _AskGemini({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg + 2), boxShadow: AppShadows.card),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg + 2),
          child: Stack(
            children: [
              const Positioned.fill(child: TurningBorder(radius: AppRadius.lg + 2, period: Duration(seconds: 8))),
              Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const _Sparkle(size: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Clear notes by Gemini', style: AppText.section),
                            const SizedBox(height: 2),
                            Text('Made from what was said, in simple words.',
                                style: AppText.small.copyWith(color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpace.l),
                    const Wrap(
                      spacing: AppSpace.s,
                      runSpacing: AppSpace.s,
                      children: [
                        _Gets(Icons.short_text_rounded, 'Summary'),
                        _Gets(Icons.format_list_numbered_rounded, 'Key points'),
                        _Gets(Icons.task_alt_rounded, 'To-do list'),
                        _Gets(Icons.push_pin_rounded, 'Dates and doses'),
                        _Gets(Icons.menu_book_rounded, 'Hard words explained'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GradientButton(label: 'Summarise with Gemini', icon: Icons.auto_awesome_rounded, onTap: onTap),
                    const SizedBox(height: 10),
                    Text('Only when you tap. It needs the internet.',
                        textAlign: TextAlign.center, style: AppText.small.copyWith(color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// One thing Gemini's notes contain (on the Summarise card).
class _Gets extends StatelessWidget {
  const _Gets(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(icon, size: 15, color: AppColors.turqDeep)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: AppText.small.copyWith(color: AppColors.ink))),
        ]),
      );
}

/// Gemini at work: the sparkle turns while light sweeps over lines that stand for the notes.
class _Writing extends StatelessWidget {
  const _Writing();

  @override
  Widget build(BuildContext context) => _Card(
        child: Semantics(
          liveRegion: true,
          label: 'Gemini is writing your notes',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const _Sparkle(size: 42, turning: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gemini is writing your notes…', style: AppText.strong.copyWith(color: AppColors.ink)),
                      Text('This takes a few seconds.', style: AppText.small.copyWith(color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: AppSpace.xl),
              const _Shimmer(lines: [1, 0.94, 0.82, 0.58, 0, 0.9, 0.72]),
            ],
          ),
        ),
      );
}

/// Placeholder lines with a band of light sweeping over them (still when motion is reduced).
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.lines});

  final List<double> lines; // each line's width, 0..1; 0 = a gap between paragraphs

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppMotion.reduced(context) ? _sweep.stop() : _sweep.repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in widget.lines)
          width == 0
              ? const SizedBox(height: 10)
              : FractionallySizedBox(
                  widthFactor: width,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: AppColors.skeleton, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
      ],
    );
    if (AppMotion.reduced(context)) return lines;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _sweep,
        child: lines,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            colors: const [AppColors.skeleton, AppColors.skeletonShine, AppColors.skeleton],
            stops: const [0.35, 0.5, 0.65],
            transform: _Slide(-1 + 2 * _sweep.value),
          ).createShader(rect),
          child: child,
        ),
      ),
    );
  }
}

/// Moves a gradient sideways by a share of the box's width.
class _Slide extends GradientTransform {
  const _Slide(this.share);

  final double share;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * share, 0, 0);
}

/// Gemini's sparkle on a small yellow disc; [turning] while it writes.
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, this.turning = false});

  final double size;
  final bool turning;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.auto_awesome_rounded, size: size * 0.5, color: AppColors.onYellow);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(gradient: AppGradients.sun, shape: BoxShape.circle, boxShadow: AppShadows.sunGlow),
        child: Center(child: turning ? Spin(period: const Duration(seconds: 3), child: icon) : icon),
      ),
    );
  }
}

/// Gemini's few sentences about the whole session: the page's lead, Gemini's colours on its edge.
class _Overview extends StatelessWidget {
  const _Overview({required this.summary, required this.onAgain});

  final NoteSummary summary;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) => _Card(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.gemini)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const _Sparkle(size: 30),
                      const SizedBox(width: 10),
                      _Heading('SUMMARY'),
                    ]),
                    const SizedBox(height: AppSpace.m),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(summary.overview, style: AppText.lead),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.line),
                    Row(children: [
                      Expanded(
                        child: Text('Made by Gemini, ${dayAndTime(summary.madeAt)}',
                            style: AppText.small.copyWith(color: AppColors.inkSoft)),
                      ),
                      TextButton.icon(
                        onPressed: onAgain,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Summarise again'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.turqInk),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// The main points, numbered.
class _KeyPoints extends StatelessWidget {
  const _KeyPoints({required this.points});

  final List<String> points;

  @override
  Widget build(BuildContext context) => _Section(
        icon: Icons.format_list_numbered_rounded,
        title: 'KEY POINTS',
        child: Column(
          children: [
            for (final (i, point) in points.indexed) ...[
              if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.line)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: ExcludeSemantics(child: Text('${i + 1}'.padLeft(2, '0'), style: AppText.numeral)),
                  ),
                  Expanded(child: Text(point, style: AppText.reading)),
                ],
              ),
            ],
          ],
        ),
      );
}

/// What to do, as a list to tick off (the ticks are kept in the note).
class _ToDo extends StatelessWidget {
  const _ToDo({required this.actions, required this.done, required this.onToggle});

  final List<String> actions;
  final Set<int> done;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final ticked = [for (var i = 0; i < actions.length; i++) if (done.contains(i)) i].length;
    return _Section(
      icon: Icons.task_alt_rounded,
      title: 'ADVICE & TO DO',
      trailing: Text('$ticked of ${actions.length} done', style: AppText.small.copyWith(color: AppColors.turqInk)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Progress(value: ticked / actions.length),
          const SizedBox(height: AppSpace.xs),
          for (final (i, action) in actions.indexed)
            _ToDoRow(text: action, done: done.contains(i), onTap: () => onToggle(i)),
        ],
      ),
    );
  }
}

/// How much of the list is done: a thin bar that slides to its new length.
class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: AppColors.line)),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: value),
                  duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.medium,
                  curve: AppMotion.outCurve,
                  builder: (context, share, _) => FractionallySizedBox(
                    widthFactor: share,
                    alignment: Alignment.centerLeft,
                    child: const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.turq)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// One thing to do: tap to tick it off (the tick pops in, the words are struck through).
class _ToDoRow extends StatelessWidget {
  const _ToDoRow({required this.text, required this.done, required this.onTap});

  final String text;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduced(context) ? Duration.zero : AppMotion.fast;
    return Semantics(
      checked: done,
      label: text,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: duration,
                  curve: AppMotion.outCurve,
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: done ? AppGradients.turq : null,
                    color: done ? null : AppColors.surface,
                    border: Border.all(color: done ? AppColors.turq : AppColors.turqDeep, width: 2),
                  ),
                  child: AnimatedScale(
                    scale: done ? 1 : 0,
                    duration: duration,
                    curve: AppMotion.springCurve,
                    child: const Icon(Icons.check_rounded, size: 16, color: AppColors.onDark),
                  ),
                ),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    style: done
                        ? AppText.reading.copyWith(
                            color: AppColors.inkSoft,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.inkSoft,
                          )
                        : AppText.reading,
                    child: Text(text),
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

/// Dates, times, numbers and doses, exactly as said. A tap copies one (for a calendar or a message).
class _Details extends StatelessWidget {
  const _Details({required this.details, required this.onCopy});

  final List<String> details;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) => _Section(
        icon: Icons.push_pin_rounded,
        title: 'IMPORTANT DETAILS',
        trailing: Text('Tap to copy', style: AppText.small.copyWith(color: AppColors.inkSoft)),
        child: Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final detail in details)
              Semantics(
                button: true,
                label: 'Copy: $detail',
                excludeSemantics: true,
                child: Material(
                  color: AppColors.yellowWash,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: InkWell(
                    onTap: () => onCopy(detail),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.content_copy_rounded, size: 15, color: AppColors.onYellow),
                          const SizedBox(width: AppSpace.s),
                          Flexible(
                            child: Text(detail, style: AppText.label.copyWith(color: AppColors.onYellow, fontSize: 14, height: 1.35)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Hard words that were said, each with a simple meaning.
class _Words extends StatelessWidget {
  const _Words({required this.terms});

  final List<SummaryTerm> terms;

  @override
  Widget build(BuildContext context) => _Section(
        icon: Icons.menu_book_rounded,
        title: 'WORDS EXPLAINED',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, t) in terms.indexed)
              Container(
                margin: EdgeInsets.only(top: i == 0 ? 0 : 10),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(color: AppColors.turqWash, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.term, style: AppText.strong.copyWith(color: AppColors.turqInk, fontSize: 15.5)),
                    const SizedBox(height: AppSpace.xs),
                    Text(t.meaning, style: AppText.reading.copyWith(fontSize: 15)),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Learn mode's Gemini Quiz for this note (README "Learn"): make one, or play the one kept.
class _QuizMe extends StatelessWidget {
  const _QuizMe({required this.note, required this.saved, required this.onQuiz, required this.onNewQuiz});

  final ListenNote note;
  final bool saved;
  final VoidCallback onQuiz;
  final VoidCallback onNewQuiz;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.blueWash, borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.quiz_rounded, color: AppColors.royal),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quiz yourself', style: AppText.section),
                    const SizedBox(height: 2),
                    Text(
                      saved
                          ? 'Your quiz of this note is saved. Play it again any time.'
                          : '${quizLength(note)} questions from this note, made by Gemini. Wins XP in Learn.',
                      style: AppText.small.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.l),
            GradientButton(
              label: saved ? 'Play quiz' : 'Make quiz',
              icon: saved ? Icons.play_arrow_rounded : Icons.quiz_rounded,
              gradient: AppGradients.blueTile,
              shadow: AppShadows.blueTile,
              onTap: onQuiz,
            ),
            if (saved)
              TextButton.icon(
                onPressed: onNewQuiz,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('New quiz from Gemini'),
                style: TextButton.styleFrom(foregroundColor: AppColors.turqInk, minimumSize: const Size.fromHeight(44)),
              ),
          ],
        ),
      );
}

/// Learn mode's lesson of the signs heard in this note (README "Learn"): which ones, and the way in.
class _SignsHeard extends StatelessWidget {
  const _SignsHeard({required this.glosses, required this.onLearn});

  final List<String> glosses;
  final VoidCallback onLearn;

  static const _shown = 6;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.yellowWash, borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.sign_language_rounded, color: AppColors.onYellowInk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Learn the signs you heard', style: AppText.section),
                    const SizedBox(height: 2),
                    Text(glosses.length == 1 ? '1 sign in this note' : '${glosses.length} signs in this note',
                        style: AppText.small.copyWith(color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.m),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final gloss in glosses.take(_shown))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text(gloss, style: AppText.label.copyWith(color: AppColors.ink)),
                  ),
                if (glosses.length > _shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                    child: Text('+${glosses.length - _shown} more', style: AppText.label.copyWith(color: AppColors.inkSoft)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.l),
            GradientButton(
              label: 'Learn them',
              icon: Icons.school_rounded,
              gradient: AppGradients.sunCta,
              shadow: AppShadows.sunCta,
              foreground: AppColors.onYellow,
              onTap: onLearn,
            ),
          ],
        ),
      );
}

/// Gemini can be wrong: the way to what was really said.
class _CheckAgainst extends StatelessWidget {
  const _CheckAgainst({required this.onSeeSaid});

  final VoidCallback onSeeSaid;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(child: Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSoft)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Gemini can make mistakes. Check doses, dates and numbers against what was said.',
                      style: AppText.body.copyWith(color: AppColors.inkSoft)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSeeSaid,
                style: TextButton.styleFrom(foregroundColor: AppColors.turqInk),
                child: const Text('See what was said'),
              ),
            ),
          ],
        ),
      );
}

/// A white card with a small heading: an icon, the title in capitals, and something on the right.
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, this.trailing, required this.child});

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ExcludeSemantics(child: Icon(icon, size: 16, color: AppColors.turqDeep)),
              const SizedBox(width: AppSpace.s),
              _Heading(title),
              if (trailing case final trailing?) trailing,
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

/// A card's title in small capitals (read out as a heading).
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          header: true,
          child: Text(text, style: AppText.eyebrow.copyWith(color: AppColors.inkSoft, fontSize: 11.5)),
        ),
      );
}

/// A white card (the page's building block).
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}
