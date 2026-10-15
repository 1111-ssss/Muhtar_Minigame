import 'package:flutter/material.dart';

import '../../domain/quest.dart';
import '../../game_logic/game_state.dart';
import '../../game/muhtar_game.dart';
import '../common/animated_overlay.dart';

/// Журнал заданий показывает принятые задания до тех пор, пока игрок сам не
/// заберёт награду. Выполненное задание остаётся в журнале с кнопкой награды.
class QuestOverlay extends StatelessWidget {
  const QuestOverlay(this.game, {super.key});

  final MuhtarGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedOverlay(
      game: game,
      overlay: MuhtarGame.overlayQuests,
      builder: (context, close) => ListenableBuilder(
        listenable: game.gameState,
        builder: (context, _) {
          final state = game.gameState;
          // Непринятые и уже забранные задания не показываются. Выполненные
          // остаются здесь, пока игрок явно не нажмёт кнопку награды.
          final all = state.quests.values
              .where(
                (progress) =>
                    progress.state == QuestState.active ||
                    progress.state == QuestState.completed,
              )
              .toList();

          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.85),
            appBar: AppBar(
              title: const Text('Задания'),
              backgroundColor: Colors.black54,
              leading: IconButton(
                tooltip: 'Закрыть (Esc)',
                icon: const Icon(Icons.close),
                onPressed: close,
              ),
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: all.isEmpty
                      ? const Center(
                          child: Text(
                            'Заданий пока нет',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: all.length,
                          itemBuilder: (context, index) {
                            final q = all[index];
                            return _QuestCard(
                              progress: q,
                              onClaim: () {
                                state.claimQuest(q.quest.id);
                              },
                            );
                          },
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.progress, required this.onClaim});

  final QuestProgress progress;
  final VoidCallback onClaim;

  String? _skinRewardId(Quest quest) {
    try {
      return (quest as dynamic).skinRewardId?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    final color = switch (progress.state) {
      QuestState.active => Colors.blue,
      QuestState.completed => Colors.green,
      QuestState.claimed => Colors.grey,
      QuestState.notStarted => Colors.grey.shade700,
    };

    return Card(
      key: ValueKey('quest-${quest.id}'),
      color: Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quest.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (progress.state == QuestState.completed)
                  FilledButton.icon(
                    key: ValueKey('claim-${quest.id}'),
                    onPressed: onClaim,
                    icon: const Icon(Icons.redeem),
                    label: const Text('Получить награду'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quest.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (progress.state != QuestState.notStarted) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.progressFraction,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final rewards = [
                    '${quest.coinReward} монет',
                    '${quest.xpReward} опыта',
                    '${quest.artifactCaseReward} кейс артефактов',
                  ];
                  final skinRewardId = _skinRewardId(quest);
                  if (skinRewardId != null && skinRewardId.isNotEmpty) {
                    rewards.add('скин «$skinRewardId»');
                  }
                  return Text(
                    '${progress.progress}/${quest.target} • награда: '
                    '${rewards.join(', ')}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
