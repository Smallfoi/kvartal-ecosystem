import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/legal_provider.dart';

/// Правовые документы экосистемы STAW — пункт в Настройках (как «Уведомления»,
/// «Конфиденциальность»). Тексты приходят с backend и редактируются в админ-панели:
/// изменил в админке → приложение показывает новую версию. Отдельной «фичи» нет.
class LegalDocumentsScreen extends ConsumerWidget {
  const LegalDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(legalDocumentsProvider);
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Документы'),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            icon: CupertinoIcons.wifi_slash,
            text: 'Не удалось загрузить документы.\nПроверьте соединение.',
            onRetry: () => ref.refresh(legalDocumentsProvider),
          ),
          data: (docs) {
            if (docs.isEmpty) {
              return const _Message(
                icon: CupertinoIcons.doc_text,
                text: 'Документы пока не опубликованы.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(legalDocumentsProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) => _DocTile(doc: docs[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final LegalDoc doc;
  const _DocTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator),
      ),
      child: ListTile(
        leading: const Icon(CupertinoIcons.doc_text,
            color: AppColors.accentBlue, size: 20),
        title: Text(
          doc.title,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textPrimary),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Text('ред. ${doc.version}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              if (doc.required) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('обязательный',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.accentBlue)),
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(CupertinoIcons.chevron_right,
            color: AppColors.textDisabled, size: 16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _LegalDocView(doc: doc)),
        ),
      ),
    );
  }
}

/// Просмотр текста документа. Тело хранится в backend (Markdown), рендерим
/// лёгким форматированием — без внешних зависимостей.
class _LegalDocView extends StatelessWidget {
  final LegalDoc doc;
  const _LegalDocView({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: Text(doc.title, style: const TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text('Редакция ${doc.version}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ..._renderMarkdown(doc.body),
          ],
        ),
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
            color: AppColors.bgSurface,
            border: Border(
                left: BorderSide(color: AppColors.accentBlue, width: 3)),
          ),
          child: SelectableText(_stripInline(line.substring(2)),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        ));
      } else if (RegExp(r'^[-*] ').hasMatch(line)) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 8),
                child: Icon(Icons.circle, size: 5, color: AppColors.accentBlue),
              ),
              Expanded(
                child: SelectableText(_stripInline(line.substring(2)),
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary, height: 1.45)),
              ),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: SelectableText(_stripInline(line),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
        ));
      }
    }
    return widgets;
  }

  Widget _h(String text, double size) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: SelectableText(_stripInline(text),
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      );

  /// Убираем простую inline-разметку (**жирный**, `код`, таблицы |).
  String _stripInline(String s) =>
      s.replaceAll('**', '').replaceAll('`', '').replaceAll('|', '  ');
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  const _Message({required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ],
      ),
    );
  }
}
