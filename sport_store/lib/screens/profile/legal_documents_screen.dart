import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/api/api_client.dart';
import '../../theme/app_theme.dart';

/// Правовые документы экосистемы STAW (соглашения, политика, согласия, оферта,
/// правила баллов/сообщества). Единый источник правды — backend: документы
/// редактируются в админ-панели, приложение всегда показывает актуальную
/// опубликованную версию (`GET /v1/legal/documents`). Отдельной «фичи» нет —
/// это пункт в Настройках, как «Уведомления» и «Конфиденциальность».
class LegalDocumentsScreen extends StatefulWidget {
  const LegalDocumentsScreen({super.key});

  @override
  State<LegalDocumentsScreen> createState() => _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends State<LegalDocumentsScreen> {
  late Future<List<_LegalDoc>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_LegalDoc>> _load() async {
    final api = context.read<ApiClient?>();
    if (api == null) return const [];
    final data = await api.get('/legal/documents');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => _LegalDoc.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'ДОКУМЕНТЫ',
          style: GoogleFonts.oswald(
            fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 3,
          ),
        ),
      ),
      body: FutureBuilder<List<_LegalDoc>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Message(
              icon: Icons.wifi_off,
              text: 'Не удалось загрузить документы.\nПроверьте соединение.',
              onRetry: _reload,
            );
          }
          final docs = snap.data ?? const <_LegalDoc>[];
          if (docs.isEmpty) {
            return const _Message(
              icon: Icons.description_outlined,
              text: 'Документы пока не опубликованы.',
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.grey100),
              itemBuilder: (context, i) => _DocTile(doc: docs[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final _LegalDoc doc;
  const _DocTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.description_outlined,
            size: 19, color: AppColors.black),
      ),
      title: Text(
        doc.title,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.black),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Text('ред. ${doc.version}',
                style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
            if (doc.required) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('обязательный',
                    style: TextStyle(fontSize: 10, color: AppColors.white)),
              ),
            ],
            if (doc.accepted == true) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, size: 14, color: AppColors.grey600),
              const SizedBox(width: 3),
              const Text('принят',
                  style: TextStyle(fontSize: 11, color: AppColors.grey600)),
            ],
          ],
        ),
      ),
      trailing:
          const Icon(Icons.chevron_right, size: 20, color: AppColors.grey400),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _LegalDocView(doc: doc)),
      ),
    );
  }
}

/// Просмотр текста документа. Тело хранится в backend (Markdown), рендерим
/// лёгким форматированием — без внешних зависимостей.
class _LegalDocView extends StatelessWidget {
  final _LegalDoc doc;
  const _LegalDocView({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          doc.title.toUpperCase(),
          style: GoogleFonts.oswald(
            fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Редакция ${doc.version}',
              style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
          const SizedBox(height: 12),
          ..._renderMarkdown(doc.body),
        ],
      ),
    );
  }

  List<Widget> _renderMarkdown(String md) {
    final widgets = <Widget>[];
    for (final rawLine in md.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('### ')) {
        widgets.add(_h(line.substring(4), 15));
      } else if (line.startsWith('## ')) {
        widgets.add(_h(line.substring(3), 17));
      } else if (line.startsWith('# ')) {
        widgets.add(_h(line.substring(2), 20));
      } else if (line.startsWith('> ')) {
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: AppColors.grey100,
            border: Border(
                left: BorderSide(color: AppColors.black, width: 3)),
          ),
          child: SelectableText(_stripInline(line.substring(2)),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.grey600, height: 1.4)),
        ));
      } else if (RegExp(r'^[-*] ').hasMatch(line)) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 8),
                child: Icon(Icons.circle, size: 5, color: AppColors.black),
              ),
              Expanded(
                child: SelectableText(_stripInline(line.substring(2)),
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.black, height: 1.45)),
              ),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: SelectableText(_stripInline(line),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.black, height: 1.5)),
        ));
      }
    }
    return widgets;
  }

  Widget _h(String text, double size) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: SelectableText(_stripInline(text),
            style: GoogleFonts.oswald(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: AppColors.black)),
      );

  /// Убираем простую inline-разметку (**жирный**, `код`, таблицы |), чтобы
  /// текст читался как обычный, без «звёздочек».
  String _stripInline(String s) =>
      s.replaceAll('**', '').replaceAll('`', '').replaceAll('|', '  ');
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Future<void> Function()? onRetry;
  const _Message({required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.grey400),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey600)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalDoc {
  final String type;
  final String title;
  final String version;
  final String body;
  final bool required;
  final bool? accepted;

  const _LegalDoc({
    required this.type,
    required this.title,
    required this.version,
    required this.body,
    required this.required,
    this.accepted,
  });

  factory _LegalDoc.fromJson(Map<String, dynamic> m) => _LegalDoc(
        type: (m['type'] ?? '').toString(),
        title: (m['title'] ?? 'Документ').toString(),
        version: (m['version'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        required: m['required'] == true,
        accepted: m['accepted'] is bool ? m['accepted'] as bool : null,
      );
}
