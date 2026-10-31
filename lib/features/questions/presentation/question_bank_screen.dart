import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../features/game/domain/game_models.dart';
import '../../../services/providers.dart';

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  List<Question> _questions = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    final repo = ref.read(questionsRepositoryProvider);
    final qs = _search.isEmpty
        ? await repo.getAllQuestions()
        : await repo.searchQuestions(_search);
    if (mounted) setState(() { _questions = qs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddEditDialog(null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              hintText: 'Search questions...',
              onChanged: (val) {
                _search = val;
                _loadQuestions();
              },
              leading: const Icon(Icons.search_rounded),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? const Center(child: Text('No questions yet.'))
                    : ListView.builder(
                        itemCount: _questions.length,
                        itemBuilder: (ctx, i) => _QuestionTile(
                          question: _questions[i],
                          onEdit: () => _showAddEditDialog(_questions[i]),
                          onDelete: () => _deleteQuestion(_questions[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditDialog(Question? question) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddEditQuestionDialog(question: question),
    );
    if (result == true) _loadQuestions();
  }

  Future<void> _deleteQuestion(Question q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: Text('Delete "${q.text.substring(0, q.text.length.clamp(0, 50))}..."?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(questionsRepositoryProvider).deleteQuestion(q.id);
      _loadQuestions();
    }
  }
}

class _QuestionTile extends StatelessWidget {
  final Question question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionTile({required this.question, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(question.text, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${question.category} • ${question.difficulty}',
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      leading: CircleAvatar(
        backgroundColor: _difficultyColor(question.difficulty).withValues(alpha: 0.2),
        child: Text(
          question.difficulty[0].toUpperCase(),
          style: TextStyle(
            color: _difficultyColor(question.difficulty),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit_rounded, size: 20), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.red), onPressed: onDelete),
        ],
      ),
    );
  }

  Color _difficultyColor(String d) => switch (d.toLowerCase()) {
    'easy' => Colors.green,
    'hard' => Colors.red,
    _ => Colors.orange,
  };
}

class _AddEditQuestionDialog extends ConsumerStatefulWidget {
  final Question? question;
  const _AddEditQuestionDialog({this.question});

  @override
  ConsumerState<_AddEditQuestionDialog> createState() => _AddEditQuestionDialogState();
}

class _AddEditQuestionDialogState extends ConsumerState<_AddEditQuestionDialog> {
  final _textCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  String _difficulty = 'medium';

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      _textCtrl.text = widget.question!.text;
      _answerCtrl.text = widget.question!.answer ?? '';
      _categoryCtrl.text = widget.question!.category;
      _difficulty = widget.question!.difficulty;
    } else {
      _categoryCtrl.text = 'General';
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose(); _answerCtrl.dispose(); _categoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'Add Question' : 'Edit Question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _textCtrl, decoration: const InputDecoration(labelText: 'Question*', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 12),
            TextField(controller: _answerCtrl, decoration: const InputDecoration(labelText: 'Answer (judge only)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _categoryCtrl, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()),
              items: ['easy', 'medium', 'hard'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) { if (v != null) setState(() => _difficulty = v); },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (_textCtrl.text.trim().isEmpty) return;
            final repo = ref.read(questionsRepositoryProvider);
            if (widget.question == null) {
              await repo.addQuestion(
                Question(
                  id: const Uuid().v4(),
                  text: _textCtrl.text.trim(),
                  answer: _answerCtrl.text.trim().isEmpty ? null : _answerCtrl.text.trim(),
                  category: _categoryCtrl.text.trim().isEmpty ? 'General' : _categoryCtrl.text.trim(),
                  difficulty: _difficulty,
                  createdAt: DateTime.now().toUtc(),
                ),
              );
            } else {
              await repo.updateQuestion(widget.question!.copyWith(
                text: _textCtrl.text.trim(),
                answer: _answerCtrl.text.trim().isEmpty ? null : _answerCtrl.text.trim(),
                category: _categoryCtrl.text.trim().isEmpty ? 'General' : _categoryCtrl.text.trim(),
                difficulty: _difficulty,
              ));
            }
            if (context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
