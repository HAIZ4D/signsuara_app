/// One answer to pick: [text] big, [detail] small under it (a sign's English meaning).
class QuizOption {
  const QuizOption(this.text, [this.detail]);

  final String text;
  final String? detail;
}

/// One question of a quiz: Teka Isyarat (the avatar signs [clipId]) or, later, the Gemini quiz
/// (text only). [answer] is the place of the right one in [options] (always 4).
class QuizQuestion {
  QuizQuestion({
    this.clipId,
    List<String>? clips,
    required this.question,
    required this.options,
    required this.answer,
    this.explain,
  })  : clips = clips ?? [if (clipId != null) clipId],
        assert(options.length == 4 && answer >= 0 && answer < 4);

  final String? clipId; // the sign asked
  final List<String> clips; // what the avatar plays for it (a letter: hand up, letter, hand down)
  final String question;
  final List<QuizOption> options;
  final int answer;
  final String? explain; // one short line shown after answering

  QuizOption get correct => options[answer];
}
