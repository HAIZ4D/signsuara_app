import 'package:flutter/foundation.dart';
import 'package:signsuara_app/cloud/account.dart';
import 'package:signsuara_app/custom/custom_gesture.dart';
import 'package:signsuara_app/custom/gesture_store.dart';
import 'package:signsuara_app/history/history_store.dart';
import 'package:signsuara_app/learn/note_quiz.dart';
import 'package:signsuara_app/learn/quiz_question.dart';
import 'package:signsuara_app/listen/listen_note.dart';
import 'package:signsuara_app/listen/note_store.dart';
import 'package:signsuara_app/listen/note_summary.dart';

const testUser = AppUser(uid: 'u1', name: 'Test User', email: 'test.user@example.com');

/// Stands in for Firebase + Google in tests: [next] is what the account picker "returns"
/// (null = the user closed it), [failure] makes sign-in fail.
class FakeAuthBackend implements AuthBackend {
  FakeAuthBackend({this.currentUser, this.next = testUser, this.failure, FakeSummarizer? summarizer})
      : fakeSummarizer = summarizer ?? FakeSummarizer();

  @override
  AppUser? currentUser;
  AppUser? next;
  SignInFailure? failure;
  var signOuts = 0;

  @override
  Future<AppUser?> signInWithGoogle() async {
    if (failure case final failure?) throw failure;
    return currentUser = next;
  }

  /// One in-memory "cloud" store per account.
  final stores = <String, MemoryHistoryStore>{};

  @override
  HistoryStore historyFor(AppUser user) => stores.putIfAbsent(user.uid, MemoryHistoryStore.new);

  /// One in-memory gesture backup per account.
  final gestureStores = <String, FakeGestureStore>{};

  @override
  GestureStore gesturesFor(AppUser user) => gestureStores.putIfAbsent(user.uid, FakeGestureStore.new);

  /// One in-memory notes store per account.
  final noteStores = <String, MemoryNoteStore>{};

  @override
  NoteStore notesFor(AppUser user) => noteStores.putIfAbsent(user.uid, MemoryNoteStore.new);

  final FakeSummarizer fakeSummarizer;

  @override
  Summarizer summarizer() => fakeSummarizer;

  final fakeQuizMaker = FakeQuizMaker();

  @override
  QuizMaker quizMaker() => fakeQuizMaker;

  /// Makes the next rename fail.
  SignInFailure? renameFailure;

  /// Makes the next photo change fail.
  SignInFailure? photoFailure;
  var photosUploaded = 0;

  @override
  Future<AppUser> setPhoto(Uint8List image) async {
    if (photoFailure case final failure?) throw failure;
    final user = currentUser!;
    photosUploaded++;
    return currentUser = AppUser(
        uid: user.uid,
        name: user.name,
        email: user.email,
        photoUrl: 'https://example.com/photo-$photosUploaded.jpg',
        customPhoto: true);
  }

  @override
  Future<AppUser> useGooglePhoto() async {
    if (photoFailure case final failure?) throw failure;
    final user = currentUser!;
    return currentUser = AppUser(uid: user.uid, name: user.name, email: user.email);
  }

  @override
  Future<AppUser> rename(String name) async {
    if (renameFailure case final failure?) throw failure;
    final user = currentUser!;
    return currentUser = AppUser(uid: user.uid, name: name, email: user.email, photoUrl: user.photoUrl);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    signOuts++;
  }
}

/// A gesture backup in memory. It keeps the database maps, so the conversion is tested too.
/// [failing] makes every call fail (e.g. no permission).
class FakeGestureStore implements GestureStore {
  final saved = <String, Map<String, Object?>>{};
  var failing = false;

  void _check() {
    if (failing) throw StateError('backup unavailable');
  }

  @override
  Future<List<CustomGesture>> loadAll() async {
    _check();
    return [for (final e in saved.entries) gestureFromBackup(e.key, e.value)!];
  }

  @override
  Future<void> save(CustomGesture gesture) async {
    _check();
    saved[gesture.id] = gestureToBackup(gesture);
  }

  @override
  Future<void> delete(String id) async {
    _check();
    saved.remove(id);
  }
}

/// Gemini in tests: returns [result] (or throws [failure]) and remembers what it was asked.
class FakeSummarizer implements Summarizer {
  FakeSummarizer({NoteSummary? result, this.failure}) : result = result ?? exampleSummary;

  NoteSummary result;
  SummaryFailure? failure;
  final asked = <ListenNote>[];

  @override
  Future<NoteSummary> summarize(ListenNote note) async {
    asked.add(note);
    if (failure case final failure?) throw failure;
    return result;
  }
}

/// Gemini's quizzes in tests: returns [result] (or throws [failure]) and remembers what it was asked.
class FakeQuizMaker implements QuizMaker {
  List<QuizQuestion> result = exampleQuiz();
  QuizFailure? failure;
  final asked = <ListenNote>[];

  @override
  Future<List<QuizQuestion>> makeQuiz(ListenNote note) async {
    asked.add(note);
    if (failure case final failure?) throw failure;
    return result;
  }
}

List<QuizQuestion> exampleQuiz() => [
      QuizQuestion(
        question: 'How often is the medicine taken?',
        options: const [QuizOption('Once a week'), QuizOption('Twice a day'), QuizOption('Only at night'), QuizOption('Never')],
        answer: 1,
        explain: 'The doctor said twice a day, after meals.',
      ),
      QuizQuestion(
        question: 'When is the next visit?',
        options: const [QuizOption('8 October'), QuizOption('1 January'), QuizOption('Tomorrow'), QuizOption('Next year')],
        answer: 0,
        explain: 'The next visit is on 8 October.',
      ),
    ];

final exampleSummary = NoteSummary(
  overview: 'The doctor explained how to take the new medicine.',
  keyPoints: const ['The medicine is for the cough.'],
  actions: const ['Take the medicine twice a day after meals.'],
  details: const ['2 times a day', 'Next visit: 8 October'],
  terms: const [SummaryTerm('Antibiotik', 'Ubat yang membunuh kuman.')],
  madeAt: DateTime(2026, 10, 1, 10),
  model: 'test-model',
);
