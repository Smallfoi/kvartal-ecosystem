import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/club_provider.dart';

class ClubScreen extends ConsumerStatefulWidget {
  const ClubScreen({super.key});

  @override
  ConsumerState<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends ConsumerState<ClubScreen> {
  final _searchCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(clubProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ClubState>(clubProvider, (previous, next) {
      final message = next.message;
      if (message != null && message != previous?.message && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    });
    final state = ref.watch(clubProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: RefreshIndicator(
        onRefresh: () => ref.read(clubProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            _ClubSliverHeader(club: state.myClub),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (state.error != null) ...[
                    _StatusCard(
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      title: 'Не удалось загрузить клубы',
                      subtitle: state.error!,
                      color: AppColors.error,
                      actionLabel: 'Повторить',
                      onAction: () => ref.read(clubProvider.notifier).refresh(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.isLoading && !state.loaded)
                    const _LoadingCard()
                  else if (state.myClub != null)
                    _MyClubBody(club: state.myClub!)
                  else
                    _DiscoverBody(
                      searchCtrl: _searchCtrl,
                      inviteCtrl: _inviteCtrl,
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showCreateClubSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _ClubFormSheet(),
  );
}

void _showEditClubSheet(BuildContext context, Club club) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ClubFormSheet(existing: club),
  );
}

void _showClubInviteSheet(BuildContext context, Club club) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ClubInviteSheet(club: club),
  );
}

class _FitText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _FitText(this.text, {this.style});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    ),
  );
}

class _ClubSliverHeader extends ConsumerWidget {
  final Club? club;
  const _ClubSliverHeader({required this.club});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClub = club != null;
    return SliverAppBar(
      expandedHeight: 218,
      pinned: true,
      backgroundColor: AppColors.bgDark,
      actions: [
        IconButton(
          tooltip: 'Обновить',
          icon: const Icon(CupertinoIcons.refresh, size: 20),
          onPressed: () => ref.read(clubProvider.notifier).refresh(),
        ),
      ],
      title: Text('Клуб', style: Theme.of(context).textTheme.titleLarge),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1F3C), Color(0xFF0A1628), AppColors.bgDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _ClubLogo(logo: club?.logo ?? 'K', size: 58),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FitText(
                              hasClub ? club!.name : '\u041a\u043b\u0443\u0431',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            _FitText(
                              hasClub
                                  ? '${club!.memberCount} \u0443\u0447\u0430\u0441\u0442\u043d\u0438\u043a\u043e\u0432'
                                  : '\u0421\u043e\u0437\u0434\u0430\u0439 \u043a\u043b\u0443\u0431 \u0438\u043b\u0438 \u043a\u043e\u043c\u0430\u043d\u0434\u0443',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (hasClub)
                        _ClubBadge(
                          label: club!.isOwner ? 'Владелец' : 'Участник',
                          color: club!.isOwner
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _ClubMetricCard(
                        icon: CupertinoIcons.star_fill,
                        label:
                            '\u0410\u043a\u0442\u0438\u0432\u043d\u043e\u0441\u0442\u044c',
                        value: hasClub ? '${club!.totalPoints}' : '0',
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _ClubMetricCard(
                        icon: CupertinoIcons.person_2_fill,
                        label: '\u0421\u043e\u0441\u0442\u0430\u0432',
                        value: hasClub ? '${club!.memberCount}' : '0',
                        color: AppColors.electricBlue,
                      ),
                      const SizedBox(width: 8),
                      _ClubMetricCard(
                        icon: hasClub && club!.isRequestOnly
                            ? CupertinoIcons.lock_fill
                            : CupertinoIcons.check_mark_circled_solid,
                        label: '\u0412\u0445\u043e\u0434',
                        value: hasClub
                            ? (club!.isRequestOnly
                                  ? '\u0417\u0430\u044f\u0432\u043a\u0430'
                                  : '\u041e\u0442\u043a\u0440\u044b\u0442')
                            : '-',
                        color: hasClub && club!.isRequestOnly
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverBody extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final TextEditingController inviteCtrl;
  const _DiscoverBody({required this.searchCtrl, required this.inviteCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clubProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusCard(
          icon: CupertinoIcons.person_2_fill,
          title:
              '\u0422\u044b \u043f\u043e\u043a\u0430 \u043d\u0435 \u0432 \u043a\u043b\u0443\u0431\u0435',
          subtitle:
              '\u0421\u043e\u0437\u0434\u0430\u0439 \u0441\u0432\u043e\u0439 \u043a\u043b\u0443\u0431 \u0438\u043b\u0438 \u043a\u043e\u043c\u0430\u043d\u0434\u0443.',
          color: AppColors.electricBlue,
          actionLabel:
              '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u043a\u043b\u0443\u0431',
          actionIcon: CupertinoIcons.plus,
          onAction: () => _showCreateClubSheet(context),
        ),
        const SizedBox(height: 16),
        _InviteCodeCard(controller: inviteCtrl),
        const SizedBox(height: 16),
        _SectionHeader(
          title:
              '\u041f\u043e\u0438\u0441\u043a \u043a\u043b\u0443\u0431\u0430',
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) =>
              ref.read(clubProvider.notifier).refresh(search: value),
          decoration: InputDecoration(
            hintText:
                '\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435 \u0438\u043b\u0438 \u0433\u043e\u0440\u043e\u0434',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            prefixIcon: const Icon(CupertinoIcons.search, size: 18),
            suffixIcon: IconButton(
              tooltip: '\u0418\u0441\u043a\u0430\u0442\u044c',
              icon: const Icon(CupertinoIcons.arrow_right_circle_fill),
              onPressed: () => ref
                  .read(clubProvider.notifier)
                  .refresh(search: searchCtrl.text),
            ),
            filled: true,
            fillColor: AppColors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.separator),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.separator),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _SectionHeader(
          title: '\u041a\u043b\u0443\u0431\u044b',
          trailing: '${state.clubs.length}',
        ),
        const SizedBox(height: 10),
        if (state.clubs.isEmpty)
          const _EmptyCard(
            title:
                '\u041a\u043b\u0443\u0431\u043e\u0432 \u043f\u043e\u043a\u0430 \u043d\u0435\u0442',
            subtitle:
                '\u0421\u043e\u0437\u0434\u0430\u0439 \u043f\u0435\u0440\u0432\u044b\u0439 \u043a\u043b\u0443\u0431.',
          )
        else
          ...state.clubs.map((club) => _ClubListTile(club: club)),
      ],
    );
  }
}

class _MyClubBody extends ConsumerWidget {
  final Club club;
  const _MyClubBody({required this.club});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clubProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (club.isOwner) ...[
          _OwnerToolsCard(club: club),
          const SizedBox(height: 14),
        ],
        if (club.description != null) ...[
          _InfoCard(text: club.description!),
          const SizedBox(height: 18),
        ],
        if (club.isOwner) ...[
          _SectionHeader(title: 'Заявки', trailing: '${state.requests.length}'),
          const SizedBox(height: 10),
          if (state.requests.isEmpty)
            const _EmptyCard(
              title: 'Заявок нет',
              subtitle: 'Новые заявки появятся здесь.',
            )
          else
            ...state.requests.map((request) => _RequestTile(request: request)),
          const SizedBox(height: 24),
        ],
        _SectionHeader(title: 'Участники', trailing: '${club.members.length}'),
        const SizedBox(height: 10),
        if (club.members.isEmpty)
          const _EmptyCard(
            title: 'Нет участников',
            subtitle: 'Список подтянется с backend.',
          )
        else
          ...club.members.map((member) => _MemberTile(member: member)),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Клубные вызовы'),
        const SizedBox(height: 10),
        const _FutureModuleCard(
          icon: CupertinoIcons.flag_fill,
          title: 'Вызовы подключим следующим этапом',
          subtitle:
              'Нужен backend для челленджей и синк пробежек, чтобы считать реальные километры клуба.',
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Захваченные районы'),
        const SizedBox(height: 10),
        const _FutureModuleCard(
          icon: CupertinoIcons.map_fill,
          title: 'Территории клуба ждут серверную геометрию',
          subtitle:
              'По D-09 владение территориями переносим на PostGIS: тогда клубные зоны станут настоящими.',
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(CupertinoIcons.square_arrow_right, size: 18),
            label: Text(
              club.isOwner && club.memberCount <= 1
                  ? 'Удалить клуб'
                  : 'Выйти из клуба',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: state.isMutating
                ? null
                : () => ref.read(clubProvider.notifier).leaveClub(),
          ),
        ),
      ],
    );
  }
}

class _OwnerToolsCard extends StatelessWidget {
  final Club club;
  const _OwnerToolsCard({required this.club});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.electricBlue.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.electricBlue.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            CupertinoIcons.slider_horizontal_3,
            size: 18,
            color: AppColors.electricBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\u0423\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0438\u0435 \u043a\u043b\u0443\u0431\u043e\u043c',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435, \u0433\u043e\u0440\u043e\u0434, \u0438\u043a\u043e\u043d\u043a\u0430 \u0438 \u043f\u0440\u0430\u0432\u0438\u043b\u0430 \u0432\u0445\u043e\u0434\u0430',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip:
              '\u041f\u0440\u0438\u0433\u043b\u0430\u0441\u0438\u0442\u044c \u0432 \u043a\u043b\u0443\u0431',
          onPressed: () => _showClubInviteSheet(context, club),
          icon: const Icon(CupertinoIcons.qrcode, size: 18),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip:
              '\u0420\u0435\u0434\u0430\u043a\u0442\u0438\u0440\u043e\u0432\u0430\u0442\u044c \u043a\u043b\u0443\u0431',
          onPressed: () => _showEditClubSheet(context, club),
          icon: const Icon(CupertinoIcons.pencil, size: 18),
        ),
      ],
    ),
  );
}

class _InviteCodeCard extends ConsumerWidget {
  final TextEditingController controller;
  const _InviteCodeCard({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clubProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.qrcode_viewfinder,
                size: 20,
                color: AppColors.electricBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '\u041a\u043e\u0434 \u0438\u043b\u0438 \u0441\u0441\u044b\u043b\u043a\u0430 \u043f\u0440\u0438\u0433\u043b\u0430\u0448\u0435\u043d\u0438\u044f',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textPrimary),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(context, ref),
            decoration: InputDecoration(
              hintText:
                  'KQ-123 \u0438\u043b\u0438 https://kvartal.app/club/...',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              prefixIcon: const Icon(CupertinoIcons.link, size: 18),
              filled: true,
              fillColor: AppColors.bgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.separator),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.separator),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: state.isMutating ? null : () => _submit(context, ref),
              icon: const Icon(CupertinoIcons.person_badge_plus, size: 18),
              label: Text(
                state.isMutating
                    ? '\u041e\u0442\u043f\u0440\u0430\u0432\u043b\u044f\u0435\u043c...'
                    : '\u0412\u0441\u0442\u0443\u043f\u0438\u0442\u044c \u043f\u043e \u043a\u043e\u0434\u0443',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context, WidgetRef ref) {
    FocusScope.of(context).unfocus();
    ref.read(clubProvider.notifier).joinByInvite(controller.text);
  }
}

class _ClubInviteSheet extends StatelessWidget {
  final Club club;
  const _ClubInviteSheet({required this.club});

  String get _link => 'https://kvartal.app/club/${club.id}';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 96),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ClubLogo(logo: club.logo, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FitText(
                        club.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\u041f\u0440\u0438\u0433\u043b\u0430\u0448\u0435\u043d\u0438\u0435 \u0432 \u043a\u043b\u0443\u0431',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '\u0417\u0430\u043a\u0440\u044b\u0442\u044c',
                  icon: const Icon(CupertinoIcons.xmark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: QrImageView(
                  data: _link,
                  version: QrVersions.auto,
                  size: 196,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF111827),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // \u0414\u043e\u0441\u0442\u0430\u0442\u043e\u0447\u043d\u043e QR-\u043a\u043e\u0434\u0430 \u0438 \u0441\u0441\u044b\u043b\u043a\u0438. \u0421\u0430\u043c\u0443 \u0441\u0441\u044b\u043b\u043a\u0443 \u043d\u0435 \u043f\u043e\u043a\u0430\u0437\u044b\u0432\u0430\u0435\u043c \u2014 \u0442\u043e\u043b\u044c\u043a\u043e
            // \u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435 \u00ab\u043a\u043e\u043f\u0438\u0440\u043e\u0432\u0430\u0442\u044c\u00bb (\u043a\u043e\u0434 \u043a\u043b\u0443\u0431\u0430 \u0443\u0431\u0440\u0430\u043b\u0438 \u0437\u0430 \u043d\u0435\u043d\u0430\u0434\u043e\u0431\u043d\u043e\u0441\u0442\u044c\u044e).
            _InviteValueCard(
              icon: CupertinoIcons.link,
              title: '\u0421\u0441\u044b\u043b\u043a\u0430 \u043f\u0440\u0438\u0433\u043b\u0430\u0448\u0435\u043d\u0438\u044f',
              value: '\u041d\u0430\u0436\u043c\u0438\u0442\u0435, \u0447\u0442\u043e\u0431\u044b \u0441\u043a\u043e\u043f\u0438\u0440\u043e\u0432\u0430\u0442\u044c',
              copyText: _link,
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteValueCard extends StatelessWidget {
  final IconData icon;
  final String title, value, copyText;
  const _InviteValueCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.copyText,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: copyText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('\u0421\u043a\u043e\u043f\u0438\u0440\u043e\u0432\u0430\u043d\u043e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _copy(context),
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.separator),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.electricBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _FitText(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip:
                  '\u0421\u043a\u043e\u043f\u0438\u0440\u043e\u0432\u0430\u0442\u044c',
              icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
              onPressed: () => _copy(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ClubListTile extends ConsumerWidget {
  final Club club;
  const _ClubListTile({required this.club});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clubProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          _ClubLogo(logo: club.logo, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FitText(
                  club.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                _FitText(
                  '${club.city ?? '\u0411\u0435\u0437 \u0433\u043e\u0440\u043e\u0434\u0430'} - ${club.memberCount} \u0447\u0435\u043b. - ${club.totalPoints} \u0431.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: state.isMutating
                ? null
                : () => ref.read(clubProvider.notifier).joinClub(club),
            child: Text(club.isRequestOnly ? 'Заявка' : 'Вступить'),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ClubMember member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final isOwner = member.role == 'owner';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.bgElevated,
            child: Text(
              member.name.trim().isEmpty ? '?' : member.name.trim()[0],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FitText(
                  member.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isOwner)
                  Text(
                    'Владелец',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.warning),
                  ),
              ],
            ),
          ),
          Text(
            '${member.points}',
            style: const TextStyle(
              color: AppColors.electricBlue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final ClubJoinRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clubProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FitText(
              request.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: 'Отклонить',
            onPressed: state.isMutating
                ? null
                : () =>
                      ref.read(clubProvider.notifier).rejectRequest(request.id),
            icon: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: AppColors.error,
            ),
          ),
          IconButton(
            tooltip: 'Одобрить',
            onPressed: state.isMutating
                ? null
                : () => ref
                      .read(clubProvider.notifier)
                      .approveRequest(request.id),
            icon: const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubFormSheet extends ConsumerStatefulWidget {
  final Club? existing;
  const _ClubFormSheet({this.existing});
  @override
  ConsumerState<_ClubFormSheet> createState() => _ClubFormSheetState();
}

class _ClubFormSheetState extends ConsumerState<_ClubFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _descriptionCtrl;
  String _logo = 'K';
  String _joinPolicy = 'open';
  String? _error;

  @override
  void initState() {
    super.initState();
    final club = widget.existing;
    _nameCtrl = TextEditingController(text: club?.name ?? '');
    _cityCtrl = TextEditingController(
      text: club?.city ?? '\u042f\u043a\u0443\u0442\u0441\u043a',
    );
    _descriptionCtrl = TextEditingController(text: club?.description ?? '');
    _logo = club?.logo ?? 'K';
    _joinPolicy = club?.joinPolicy ?? 'open';
  }

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введи название клуба');
      return;
    }
    final notifier = ref.read(clubProvider.notifier);
    if (_isEdit) {
      await notifier.updateClub(
        name: name,
        city: _cityCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        logo: _logo,
        joinPolicy: _joinPolicy,
      );
    } else {
      await notifier.createClub(
        name: name,
        city: _cityCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        logo: _logo,
        joinPolicy: _joinPolicy,
      );
    }
    if (!mounted) return;
    if (ref.read(clubProvider).error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = ref.read(clubProvider).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final bottomGap = bottom > 0 ? 16.0 : 96.0;
    final state = ref.watch(clubProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + bottomGap),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _isEdit
                      ? '\u0420\u0435\u0434\u0430\u043a\u0442\u0438\u0440\u043e\u0432\u0430\u0442\u044c \u043a\u043b\u0443\u0431'
                      : '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u043a\u043b\u0443\u0431',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Закрыть',
                  icon: const Icon(CupertinoIcons.xmark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EditField(
              controller: _nameCtrl,
              label: 'Название клуба',
              icon: CupertinoIcons.person_2_fill,
            ),
            const SizedBox(height: 10),
            _EditField(
              controller: _cityCtrl,
              label: 'Город',
              icon: CupertinoIcons.location_fill,
            ),
            const SizedBox(height: 10),
            _EditField(
              controller: _descriptionCtrl,
              label: 'Описание',
              icon: CupertinoIcons.text_alignleft,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _LogoPicker(
              value: _logo,
              onChanged: (value) => setState(() => _logo = value),
            ),
            const SizedBox(height: 14),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _joinPolicy,
              children: const {
                'open': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Открытый'),
                ),
                'request': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('По заявке'),
                ),
              },
              onValueChanged: (value) {
                if (value != null) setState(() => _joinPolicy = value);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: state.isMutating ? null : _save,
                child: state.isMutating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isEdit
                            ? '\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c'
                            : '\u0421\u043e\u0437\u0434\u0430\u0442\u044c',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _LogoPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const logos = [
      'K',
      'Q',
      'RUN',
      '\u{26A1}',
      '\u{1F43A}',
      '\u{1F43B}',
      '\u{1F98A}',
      '\u{1F989}',
      '\u{1F3D4}',
      '\u{1F525}',
      '\u{1F3C3}',
      '\u{2B50}',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ClubLogo(logo: value, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u041b\u043e\u0433\u043e\u0442\u0438\u043f \u043a\u043b\u0443\u0431\u0430',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\u0412\u044b\u0431\u0435\u0440\u0438 \u043f\u0440\u0435\u0441\u0435\u0442. \u0421\u0432\u043e\u0451 \u0444\u043e\u0442\u043e \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0438\u043c \u0447\u0435\u0440\u0435\u0437 \u0445\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(CupertinoIcons.photo_fill, size: 18),
            label: const Text(
              '\u0417\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0441\u0432\u043e\u0451 \u0444\u043e\u0442\u043e',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: logos.map((logo) {
              final selected = logo == value;
              return GestureDetector(
                onTap: () => onChanged(logo),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 48,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.electricBlue.withValues(alpha: 0.20)
                        : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.electricBlue
                          : AppColors.separator,
                    ),
                  ),
                  child: Text(
                    logo,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(color: AppColors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      filled: true,
      fillColor: AppColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.separator),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.separator),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader({required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      if (trailing != null)
        Text(
          trailing!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
    ],
  );
}

class _ClubMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ClubMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: _FitText(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _FitText(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClubLogo extends StatelessWidget {
  final String logo;
  final double size;
  const _ClubLogo({required this.logo, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.electricBlue.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.45)),
    ),
    alignment: Alignment.center,
    child: Text(
      logo,
      style: TextStyle(
        fontSize: size * 0.32,
        fontWeight: FontWeight.w900,
        color: AppColors.electricBlue,
      ),
    ),
  );
}

class _ClubBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ClubBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    icon: Icon(
                      actionIcon ?? CupertinoIcons.arrow_right,
                      size: 17,
                    ),
                    label: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  final String title, subtitle;
  const _EmptyCard({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => _StatusCard(
    icon: CupertinoIcons.circle,
    title: title,
    subtitle: subtitle,
    color: AppColors.textTertiary,
  );
}

class _InfoCard extends StatelessWidget {
  final String text;
  const _InfoCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.separator),
    ),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    ),
  );
}

class _FutureModuleCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _FutureModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => _StatusCard(
    icon: icon,
    title: title,
    subtitle: subtitle,
    color: AppColors.info,
  );
}
