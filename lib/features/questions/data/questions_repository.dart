import 'package:uuid/uuid.dart';
import 'package:quiz_buzzer/services/database_service.dart';
import 'package:quiz_buzzer/features/game/domain/game_models.dart';

const _uuid = Uuid();

/// Repository managing questions storage, search, filter, and initial seeding.
class QuestionsRepository {
  final DatabaseService _dbService;

  QuestionsRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<List<Question>> getAllQuestions() => _dbService.getAllQuestions();

  Future<List<Question>> getActiveQuestions() => _dbService.getActiveQuestions();

  Future<Question?> getQuestionById(String id) => _dbService.getQuestion(id);

  Future<void> addQuestion(Question question) =>
      _dbService.insertQuestion(question);

  Future<void> updateQuestion(Question question) =>
      _dbService.updateQuestion(question);

  Future<void> deleteQuestion(String id) => _dbService.deleteQuestion(id);

  /// Search questions by text or explanation or category.
  Future<List<Question>> searchQuestions(String query) async {
    final db = await _dbService.database;
    final term = '%${query.trim()}%';
    final results = await db.query(
      'questions',
      where: 'text LIKE ? OR explanation LIKE ? OR category LIKE ?',
      whereArgs: [term, term, term],
      orderBy: 'created_at ASC',
    );
    return results.map((m) => Question.fromMap(m)).toList();
  }

  /// Filter questions by optional [category] and [difficulty].
  Future<List<Question>> filterQuestions({
    String? category,
    String? difficulty,
  }) async {
    final db = await _dbService.database;
    final whereClauses = <String>['is_active = 1'];
    final whereArgs = <dynamic>[];

    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (difficulty != null && difficulty.isNotEmpty && difficulty != 'All') {
      whereClauses.add('difficulty = ?');
      whereArgs.add(difficulty);
    }

    final results = await db.query(
      'questions',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at ASC',
    );
    return results.map((m) => Question.fromMap(m)).toList();
  }

  /// Seeds 10 general knowledge questions if the questions table is empty.
  Future<void> seedSampleQuestionsIfEmpty() async {
    final existing = await getAllQuestions();
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    final sampleQuestions = [
      Question(
        id: _uuid.v4(),
        text: 'ما هي عاصمة فرنسا؟',
        answer: 'باريس',
        explanation: 'باريس هي عاصمة جمهورية فرنسا وأكبر مدنها.',
        category: 'جغرافيا',
        difficulty: 'easy',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'ما هو أسرع طائر في العالم؟',
        answer: 'صقر الشاهين',
        explanation: 'تصل سرعة صقر الشاهين عند الانقضاض إلى أكثر من 380 كم/ساعة.',
        category: 'علوم',
        difficulty: 'medium',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'كم عدد قارات العالم؟',
        answer: '7 قارات',
        explanation: 'القارات السبع هي: آسيا، إفريقيا، أمريكا الشمالية، أمريكا الجنوبية، القارة القطبية الجنوبية، أوروبا، أستراليا.',
        category: 'جغرافيا',
        difficulty: 'easy',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'ما هو أطول نهر في العالم؟',
        answer: 'نهر النيل',
        explanation: 'يبلغ طول نهر النيل حوالي 6650 كيلومتر ويقع في قارة إفريقيا.',
        category: 'جغرافيا',
        difficulty: 'medium',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'ما هو أكبر كوكب في المجموعة الشمسية؟',
        answer: 'كوكب المشتري',
        explanation: 'المشتري هو أضخم كواكب المجموعة الشمسية وكتلته تعادل أكثر من ضعفي جميع الكواكب مجتمعة.',
        category: 'علوم وفضاء',
        difficulty: 'easy',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'في أي عام هبط الإنسان على سطح القمر لأول مرة؟',
        answer: '1969',
        explanation: 'هبط نيل أرمسترونغ وباز ألدرين على سطح القمر في 20 يوليو 1969 ضمن مهمة أبولو 11.',
        category: 'تاريخ',
        difficulty: 'medium',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'ما هو العنصر الكيميائي الأكثر وفرة في الكون؟',
        answer: 'الهيدروجين',
        explanation: 'يشكل الهيدروجين ما يقارب 75% من الكتلة العنصرية للكون.',
        category: 'علوم',
        difficulty: 'hard',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'ما هي العملة الرسمية لدولة اليابان؟',
        answer: 'الين الياباني',
        explanation: 'الين هو العملة الرسمية في اليابان وثالث أكثر العملات تداولاً في العالم.',
        category: 'اقتصاد',
        difficulty: 'easy',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'كم عدد عظام جسم الإنسان البالغ؟',
        answer: '206 عظمة',
        explanation: 'يولد الإنسان بحوالي 270 عظمة تلتحم مع النمو لتصبح 206 عظمة عند البلوغ.',
        category: 'أحياء وصحة',
        difficulty: 'medium',
        createdAt: now,
      ),
      Question(
        id: _uuid.v4(),
        text: 'ما هو المحيط الأكبر في العالم من حيث المساحة؟',
        answer: 'المحيط الهادئ',
        explanation: 'يغطي المحيط الهادئ أكثر من ثلث مساحة الكرة الأرضية.',
        category: 'جغرافيا',
        difficulty: 'easy',
        createdAt: now,
      ),
    ];

    for (final q in sampleQuestions) {
      await addQuestion(q);
    }
  }
}
