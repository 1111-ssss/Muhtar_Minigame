import 'package:flutter/material.dart';

import '../../domain/artifact.dart';
import '../../domain/dice.dart';
import '../../domain/game_content.dart';
import '../../domain/quest.dart';
import '../../domain/shop_item.dart';
import '../../game/muhtar_game.dart';
import '../../game_logic/game_state.dart';
import '../battle/dice_visual.dart';
import '../common/animated_overlay.dart';
import '../common/game_symbols.dart';
import 'case_opening_dialog.dart';

/// Общий инвентарь и торговая секция Арианы.
class UpgradeOverlay extends StatefulWidget {
  const UpgradeOverlay(
    this.game, {
    this.shop = false,
    this.shopNpcId,
    super.key,
  });
  final MuhtarGame game;
  final bool shop;
  final String? shopNpcId;

  @override
  State<UpgradeOverlay> createState() => _UpgradeOverlayState();
}

class _UpgradeOverlayState extends State<UpgradeOverlay> {
  bool _opening = false;
  bool _mergeMode = false;
  final Set<int> _selectedDice = <int>{};

  Future<void> _open(CaseType type) async {
    if (_opening) return;
    final state = widget.game.gameState;
    final dice = type == CaseType.dice ? state.openDiceBox() : null;
    final choices = type == CaseType.artifact
        ? state.openArtifactBox()
        : <Artifact>[];
    if (dice == null &&
        choices.isEmpty &&
        !state.hasPendingModifierChoice) {
      return;
    }
    setState(() => _opening = true);
    widget.game.modalDialogOpen = true;
    try {
      // Сначала фиксируем результат. Перезапуск не даёт новый бросок ящика.
      await widget.game.saveProgress();
      if (!mounted) return;
      if (dice != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DiceCaseDialog(result: dice),
        );
      } else {
        if (state.pendingModifier != null) {
          await _applyPendingModifier(state, showRoll: false);
          return;
        }
        final chosen = await showDialog<Object>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ArtifactCaseDialog(
            choices: choices,
            showModifier: state.hasPendingModifierChoice,
          ),
        );
        if (chosen is Artifact && state.chooseArtifact(chosen)) {
          await widget.game.saveProgress();
        } else if (chosen == ArtifactBoxChoice.modifier) {
          await _applyPendingModifier(state);
        }
      }
    } finally {
      widget.game.modalDialogOpen = false;
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _applyPendingModifier(
    GameState state, {
    bool showRoll = true,
  }) async {
    final modifier = state.rollModifier();
    if (modifier == null) return;
    if (showRoll) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ModifierRollDialog(result: modifier),
      );
    }
    if (!mounted) return;
    final target = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DiceModifierTargetDialog(dice: state.inventory),
    );
    if (target != null && state.applyPendingModifier(target)) {
      await widget.game.saveProgress();
    }
  }

  void _purchase(String itemId) {
    final purchased = widget.game.gameState.buyShopItem(itemId);
    if (purchased && itemId == 'shaurma') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.game.openShawarmaChoice();
      });
    }
  }

  void _purchaseUpgrade(bool Function() action) {
    action();
  }

  void _toggleMergeMode() {
    setState(() {
      _mergeMode = !_mergeMode;
      _selectedDice.clear();
    });
  }

  bool _canMergeIndex(List<Dice> dice, int index) {
    final candidate = dice[index];
    return candidate.canUpgrade &&
        dice.asMap().entries.any(
          (entry) =>
              entry.key != index &&
              entry.value.ability == candidate.ability &&
              entry.value.level == candidate.level,
        );
  }

  List<int> _visibleDice(GameState state) {
    final dice = state.inventory;
    final indexes = [for (var i = 0; i < dice.length; i++) i];
    if (_mergeMode) {
      indexes.removeWhere((index) => !_canMergeIndex(dice, index));
      if (_selectedDice.length == 1) {
        final selected = dice[_selectedDice.first];
        indexes.removeWhere(
          (index) =>
              dice[index].ability != selected.ability ||
              dice[index].level != selected.level,
        );
      }
    }
    // In обычном режиме уровень — главный ориентир, а исходный порядок
    // сохраняется внутри одинаковых уровней. В режиме объединения порядок
    // остаётся тем же, чтобы выбор индексов был устойчивым до подтверждения.
    if (!_mergeMode) {
      indexes.sort((a, b) {
        final level = dice[b].level.compareTo(dice[a].level);
        return level == 0 ? a.compareTo(b) : level;
      });
    }
    return indexes;
  }

  void _selectDice(int index, GameState state) {
    if (!_mergeMode || !_canMergeIndex(state.inventory, index)) return;
    if (_selectedDice.length == 1) {
      final first = state.inventory[_selectedDice.first];
      final second = state.inventory[index];
      if (first.ability != second.ability || first.level != second.level) {
        return;
      }
    }
    setState(() {
      if (_selectedDice.contains(index)) {
        _selectedDice.remove(index);
      } else if (_selectedDice.length < 2) {
        _selectedDice.add(index);
      }
    });
  }

  void _mergeSelected(GameState state) {
    if (!_mergeMode || _selectedDice.length != 2) return;
    final selected = _selectedDice.toList(growable: false);
    if (state.mergeDice(selected[0], selected[1])) {
      setState(() => _selectedDice.clear());
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedOverlay(
    game: widget.game,
    overlay: widget.shop
        ? MuhtarGame.overlayUpgrade
        : MuhtarGame.overlayInventory,
    builder: (context, close) => ListenableBuilder(
      listenable: widget.game.gameState,
      builder: (context, _) {
        final state = widget.game.gameState;
        final visibleDice = _visibleDice(state);
        return Scaffold(
          backgroundColor: const Color(0xFF141720),
          appBar: AppBar(
            backgroundColor: const Color(0xFF202332),
            title: Text(
              widget.shop
                  ? switch (widget.shopNpcId) {
                      'baba_galya' => 'Магазин Бабы Гали',
                      'alenka' => 'Копеечка · магазин',
                      'shaurmek' => 'Донер · магазин Шаурмека',
                      _ => 'Шоп Арианы',
                    }
                  : 'Инвентарь',
            ),
            leading: IconButton(
              tooltip: 'Закрыть',
              onPressed: close,
              icon: const Icon(Icons.close),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '${state.coins} монет',
                    style: const TextStyle(color: Color(0xFFFFD18A)),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    if (widget.shop) ...[
                      const _Section('Покупки'),
                      _ShopGrid(
                        state: state,
                        npcId: widget.shopNpcId ?? 'ariana',
                        onPurchase: _purchase,
                        onUpgrade: _purchaseUpgrade,
                      ),
                      const SizedBox(height: 8),
                    ],
                    _SkinSelectionPanel(
                      state: state,
                      onSelect: (skinId) => _selectSkin(state, skinId),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 760;
                        final inventory = _InventoryPanel(
                          state: state,
                          mergeMode: _mergeMode,
                          selectedDice: _selectedDice,
                          visibleDice: visibleDice,
                          onMergePressed: () => _mergeMode
                              ? _mergeSelected(state)
                              : _toggleMergeMode(),
                          onExitMerge: _toggleMergeMode,
                          onDiceTap: (index) => _selectDice(index, state),
                          onOpenCase: _open,
                          opening: _opening,
                        );
                        final side = _mergeMode
                            ? _MergePanel(
                                dice: state.inventory,
                                selectedDice: _selectedDice.toList(),
                              )
                            : _ArtifactPanel(state: state);
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: inventory),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: side),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            inventory,
                            const SizedBox(height: 16),
                            side,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _selectSkin(GameState state, String skinId) async {
    dynamic result;
    try {
      result = (state as dynamic).selectSkin(skinId);
      if (result is Future) result = await result;
    } catch (_) {
      return;
    }
    if (result == false || !mounted) return;
    await widget.game.saveProgress();
  }
}

/// Временной адаптер для API скинов. Он намеренно живёт в UI: пока GameState
/// ещё не содержит эти поля, старые сохранения и старые тестовые состояния
/// продолжают открывать инвентарь, а будущий API подключается без миграции
/// конструкторов оверлея.
dynamic _tryRead(dynamic Function() read) {
  try {
    return read();
  } catch (_) {
    return null;
  }
}

List<String> _skinIds(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .map((item) => _skinValue(item, 'id') ?? item.toString())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

String? _skinValue(dynamic skin, String key) {
  if (skin is String) return key == 'id' ? skin : null;
  if (skin is Map) return skin[key]?.toString();
  final value = _tryRead(() {
    final dynamic object = skin;
    return switch (key) {
      'id' => object.id,
      'name' => object.name,
      'description' => object.description,
      _ => null,
    };
  });
  return value?.toString();
}

class _SkinSelectionPanel extends StatelessWidget {
  const _SkinSelectionPanel({required this.state, required this.onSelect});

  final GameState state;
  final Future<void> Function(String skinId) onSelect;

  @override
  Widget build(BuildContext context) {
    final dynamic dynamicState = state;
    final availableValue = _tryRead(() => dynamicState.availableSkins);
    final available = availableValue is Iterable
        ? availableValue.toList(growable: false)
        : GameContent.skinCatalog;
    final owned = _skinIds(_tryRead(() => dynamicState.ownedSkinIds));
    final selected = _tryRead(() => dynamicState.selectedSkinId)?.toString();

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('Образ героя', Icons.palette_outlined),
          const SizedBox(height: 6),
          const Text(
            'Выберите открытый скин для героя на карте.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          if (available.isEmpty)
            const Text(
              'Скины появятся после подключения каталога образов.',
              style: TextStyle(color: Colors.white54),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final skin in available)
                  _SkinTile(
                    id: _skinValue(skin, 'id') ?? skin.toString(),
                    title: _skinValue(skin, 'name') ?? 'Скин',
                    description: _skinValue(skin, 'description'),
                    owned: owned.contains(
                      _skinValue(skin, 'id') ?? skin.toString(),
                    ),
                    selected:
                        selected == (_skinValue(skin, 'id') ?? skin.toString()),
                    onSelect: onSelect,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.id,
    required this.title,
    required this.description,
    required this.owned,
    required this.selected,
    required this.onSelect,
  });

  final String id;
  final String title;
  final String? description;
  final bool owned;
  final bool selected;
  final Future<void> Function(String skinId) onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      color: selected ? const Color(0xFF263F48) : const Color(0xFF242737),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.person,
                  color: selected
                      ? const Color(0xFF78F3D0)
                      : const Color(0xFFFFD58E),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton(
              key: ValueKey('skin-select-$id'),
              onPressed: owned && !selected ? () => onSelect(id) : null,
              child: Text(
                selected
                    ? 'Выбран'
                    : owned
                    ? 'Выбрать'
                    : 'Не открыт',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    ),
  );
}

class _Purchase extends StatelessWidget {
  const _Purchase({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.price,
    this.maxed = false,
    this.onBuy,
  });
  final String title;
  final String description;
  final IconData icon;
  final int price;
  final bool maxed;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFC857)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onBuy,
            child: Text(maxed ? 'Максимум' : 'Купить · $price монет'),
          ),
        ],
      ),
    ),
  );
}

class _ShopGrid extends StatelessWidget {
  const _ShopGrid({
    required this.state,
    required this.npcId,
    required this.onPurchase,
    required this.onUpgrade,
  });
  final GameState state;
  final String npcId;
  final ValueChanged<String> onPurchase;
  final void Function(bool Function()) onUpgrade;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 560
          ? 2
          : 1;
      final specialItems = GameContent.shopItemsForNpc(npcId);
      if (npcId != 'ariana') {
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1
              ? 2.35
              : columns == 2
              ? 1.75
              : 1.65,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final item in specialItems)
              _ShopItemPurchase(
                item: item,
                state: state,
                onBuy: () => onPurchase(item.id),
              ),
          ],
        );
      }
      return GridView.count(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: columns == 1
            ? 2.35
            : columns == 2
            ? 1.75
            : 1.65,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _Purchase(
            title: 'Ящик костей',
            description: 'Случайный тип и уровень 1–3.',
            icon: Icons.inventory_2_outlined,
            price: GameState.caseCost,
            onBuy: state.coins >= GameState.caseCost
                ? () => onUpgrade(state.buyDiceBox)
                : null,
          ),
          _Purchase(
            key: const ValueKey('shop-upgrade-hotbar'),
            title: 'Хотбар: ${state.dicePerTurn}/${GameState.maxDicePerTurn}',
            description: 'Ещё одно место для кости.',
            icon: Icons.grid_view,
            price: state.diceUpgradeCost,
            maxed: state.dicePerTurn == GameState.maxDicePerTurn,
            onBuy:
                state.dicePerTurn < GameState.maxDicePerTurn &&
                    state.coins >= state.diceUpgradeCost
                ? () => onUpgrade(state.upgradeDicePerTurn)
                : null,
          ),
          _Purchase(
            title: 'Рероллы: ${state.rerollsPerRound}/6',
            description: 'Ещё один переброс за раунд.',
            icon: Icons.refresh,
            price: state.rerollUpgradeCost,
            maxed: state.rerollsPerRound == 6,
            onBuy:
                state.rerollsPerRound < 6 &&
                    state.coins >= state.rerollUpgradeCost
                ? () => onUpgrade(state.upgradeRerolls)
                : null,
          ),
        ],
      );
    },
  );
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.state,
    required this.mergeMode,
    required this.selectedDice,
    required this.visibleDice,
    required this.onMergePressed,
    required this.onExitMerge,
    required this.onDiceTap,
    required this.onOpenCase,
    required this.opening,
  });

  final GameState state;
  final bool mergeMode;
  final Set<int> selectedDice;
  final List<int> visibleDice;
  final VoidCallback onMergePressed;
  final VoidCallback onExitMerge;
  final ValueChanged<int> onDiceTap;
  final Future<void> Function(CaseType) onOpenCase;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final itemEntries = state.items.entries.toList(growable: false);
    final itemCount = mergeMode
        ? visibleDice.length
        : CaseType.values.length + itemEntries.length + visibleDice.length;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _PanelTitle('Инвентарь', Icons.backpack)),
              if (mergeMode)
                IconButton(
                  tooltip: 'Выйти из режима объединения',
                  onPressed: onExitMerge,
                  icon: const Icon(Icons.close),
                ),
              FilledButton.icon(
                onPressed: mergeMode && selectedDice.length == 2
                    ? onMergePressed
                    : mergeMode
                    ? null
                    : onMergePressed,
                style: FilledButton.styleFrom(
                  backgroundColor: mergeMode
                      ? const Color(0xFF7658E8)
                      : const Color(0xFF343A52),
                  foregroundColor: Colors.white,
                  side: mergeMode
                      ? const BorderSide(color: Color(0xFFB9A9FF), width: 2)
                      : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: Icon(mergeMode ? Icons.auto_awesome : Icons.merge_type),
                label: Text(
                  mergeMode
                      ? selectedDice.length == 2
                            ? 'Объединить · 2'
                            : 'Объединение · ${selectedDice.length}/2'
                      : 'Объединить',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mergeMode
                ? 'Выберите две одинаковые кости. Совместимые варианты подсвечены.'
                : 'Ящики отображаются первыми, затем предметы и кости — '
                      'от высокого уровня к низкому.',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 16),
          if (itemCount == 0)
            Text(
              mergeMode ? 'Пока нет пары для объединения.' : 'Инвентарь пуст.',
              style: const TextStyle(color: Colors.white54),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemCount,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisExtent: 168,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, item) {
                if (!mergeMode && item < CaseType.values.length) {
                  return _CaseTile(
                    type: CaseType.values[item],
                    count: state.boxCount(CaseType.values[item]),
                    pending:
                        CaseType.values[item] == CaseType.artifact &&
                        state.pendingArtifactChoices.isNotEmpty,
                    disabled: opening,
                    onOpen: () => onOpenCase(CaseType.values[item]),
                  );
                }
                final itemIndex = item - CaseType.values.length;
                if (!mergeMode && itemIndex < itemEntries.length) {
                  final entry = itemEntries[itemIndex];
                  return _ItemInventoryTile(
                    itemId: entry.key,
                    count: entry.value,
                  );
                }
                final dicePosition = mergeMode
                    ? item
                    : itemIndex - itemEntries.length;
                final diceIndex = visibleDice[dicePosition];
                return _DiceInventoryTile(
                  index: diceIndex,
                  dice: state.inventory[diceIndex],
                  selected: selectedDice.contains(diceIndex),
                  mergeMode: mergeMode,
                  onTap: () => onDiceTap(diceIndex),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ShopItemPurchase extends StatelessWidget {
  const _ShopItemPurchase({
    required this.item,
    required this.state,
    required this.onBuy,
  });

  final ShopItem item;
  final GameState state;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final purchased = state.hasPurchasedShopItem(item.id);
    final canBuy = state.canBuyShopItem(item.id);
    final lockedByQuest =
        item.requiredQuestId != null &&
        state.quest(item.requiredQuestId!)?.state != QuestState.active;
    final shortage = item.price - state.coins;
    final fullHealth =
        item.effect == ShopEffect.heal && state.playerHp >= state.playerMaxHp;
    final label = purchased
        ? 'Куплено'
        : lockedByQuest
        ? 'Сначала возьмите задание'
        : fullHealth
        ? 'Здоровье полное'
        : shortage > 0
        ? 'Не хватает монет: $shortage'
        : canBuy
        ? 'Купить · ${item.price} монет'
        : 'Недоступно';
    final icon = switch (item.effect) {
      ShopEffect.heal => Icons.favorite,
      ShopEffect.increaseMaxHp => Icons.favorite_border,
      ShopEffect.addItem => Icons.card_giftcard,
      ShopEffect.damage => Icons.local_drink,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFFFC857)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.description),
            const SizedBox(height: 12),
            if (purchased)
              const Text('Куплено', style: TextStyle(color: Color(0xFF7DFFC1)))
            else
              FilledButton(
                key: ValueKey('shop-buy-${item.id}'),
                onPressed: canBuy ? onBuy : null,
                child: Text(label),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({
    required this.type,
    required this.count,
    required this.pending,
    required this.disabled,
    required this.onOpen,
  });

  final CaseType type;
  final int count;
  final bool pending;
  final bool disabled;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final available = count > 0 || pending;
    return Semantics(
      button: true,
      enabled: available && !disabled,
      label: '${type.title}, $count',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('inventory-case-${type.name}'),
          borderRadius: BorderRadius.circular(14),
          onTap: available && !disabled ? onOpen : null,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: type == CaseType.dice
                    ? const [Color(0xFF454A79), Color(0xFF25283F)]
                    : const [Color(0xFF6B4D62), Color(0xFF30253F)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: available ? const Color(0xFFD1A86A) : Colors.white12,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  offset: Offset(3, 4),
                  blurRadius: 7,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type == CaseType.dice
                        ? Icons.inventory_2_rounded
                        : Icons.auto_awesome_mosaic_rounded,
                    size: 42,
                    color: available ? const Color(0xFFFFD58E) : Colors.white24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pending ? 'Выбор награды · $count' : '×$count',
                    style: TextStyle(
                      color: available
                          ? const Color(0xFFFFD58E)
                          : Colors.white38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    pending ? 'Продолжить' : 'Нажмите, чтобы открыть',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
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

class _DiceInventoryTile extends StatelessWidget {
  const _DiceInventoryTile({
    required this.index,
    required this.dice,
    required this.selected,
    required this.mergeMode,
    required this.onTap,
  });

  final int index;
  final Dice dice;
  final bool selected;
  final bool mergeMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: mergeMode,
    selected: selected,
    label: '${dice.name}, уровень ${dice.level}, ${dice.modifier.title}',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('inventory-dice-$index'),
        borderRadius: BorderRadius.circular(14),
        onTap: mergeMode ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF242737),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF78F3D0)
                  : const Color(0xFF4A506D),
              width: selected ? 3 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x9978F3D0),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Colors.black38,
                      offset: Offset(2, 3),
                      blurRadius: 5,
                    ),
                  ],
          ),
          child: Column(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DiceVisual(
                    dice: dice,
                    compact: true,
                    selected: selected,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dice.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Уровень ${dice.level} · ${dice.modifier.title}',
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF78F3D0)
                      : const Color(0xFFFFD58E),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ItemInventoryTile extends StatelessWidget {
  const _ItemInventoryTile({required this.itemId, required this.count});

  final String itemId;
  final int count;

  static String _titleFor(String itemId) => switch (itemId) {
    'potato' => 'Картошка',
    'sync_async' => 'SyncAsync',
    'alpen_gold' => 'Альпен Гольд',
    'shaurma' => 'Шаурма',
    _ => itemId,
  };

  static String _descriptionFor(String itemId) => switch (itemId) {
    'potato' => 'Найденный предмет',
    'sync_async' => 'Найденный предмет',
    'alpen_gold' => 'Предмет для задания',
    'shaurma' => 'Предмет для задания',
    _ => 'Предмет',
  };

  @override
  Widget build(BuildContext context) {
    final title = _titleFor(itemId);
    return Semantics(
      label: '$title, количество $count',
      child: Ink(
        key: ValueKey('inventory-item-$itemId'),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A3B35), Color(0xFF28252D)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD18A4D)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              offset: Offset(2, 3),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_rounded,
              size: 44,
              color: Color(0xFFFFD18A),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '×$count',
              style: const TextStyle(
                color: Color(0xFFFFD18A),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _descriptionFor(itemId),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtifactPanel extends StatelessWidget {
  const _ArtifactPanel({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PanelTitle('Артефакты', Icons.auto_awesome),
        const SizedBox(height: 6),
        const Text(
          'Пассивные эффекты героя, редкость и количество.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        if (state.artifacts.isEmpty)
          const Text(
            'Ящики артефактов выдаются за задания.',
            style: TextStyle(color: Colors.white54),
          )
        else
          for (final entry in state.artifacts.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF242737),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF56466B)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArtifactBadge(entry.key, count: entry.value, size: 50),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key.title} · ${entry.key.rarity.title} '
                          '×${entry.value}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.key.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class _MergePanel extends StatelessWidget {
  const _MergePanel({required this.dice, required this.selectedDice});
  final List<Dice> dice;
  final List<int> selectedDice;

  @override
  Widget build(BuildContext context) {
    Dice? preview;
    if (selectedDice.isNotEmpty && selectedDice.first < dice.length) {
      final source = dice[selectedDice.first];
      if (source.canUpgrade) preview = source.copyWith(level: source.level + 1);
    }
    return _Panel(
      child: Column(
        children: [
          const _PanelTitle('Объединение', Icons.auto_awesome),
          const SizedBox(height: 8),
          const Text(
            'Соберите две одинаковые кости в одну более сильную.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 18),
          const Text('Результат', style: TextStyle(color: Color(0xFFFFD58E))),
          const SizedBox(height: 8),
          _MergeSlot(
            dice: preview,
            label: preview == null ? 'Выберите пару' : 'Ур. ${preview.level}',
            highlight: preview != null,
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MergeSlot(
                dice:
                    selectedDice.isNotEmpty && selectedDice.first < dice.length
                    ? dice[selectedDice.first]
                    : null,
                label: 'Кость 1',
              ),
              const SizedBox(width: 14),
              _MergeSlot(
                dice: selectedDice.length > 1 && selectedDice[1] < dice.length
                    ? dice[selectedDice[1]]
                    : null,
                label: 'Кость 2',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            selectedDice.length == 2
                ? 'Нажмите «Объединить» слева, чтобы создать результат.'
                : 'Нижние ячейки заполняются выбором костей в сетке.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MergeSlot extends StatelessWidget {
  const _MergeSlot({
    required this.dice,
    required this.label,
    this.highlight = false,
  });
  final Dice? dice;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    height: 128,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1F2D),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: highlight ? const Color(0xFFFFD58E) : const Color(0xFF535A78),
        width: highlight ? 2 : 1,
      ),
      boxShadow: highlight
          ? const [BoxShadow(color: Color(0x66765CE8), blurRadius: 14)]
          : null,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (dice != null)
          FittedBox(
            child: DiceVisual(dice: dice!, compact: true, selected: highlight),
          )
        else
          const Icon(Icons.add_circle_outline, color: Colors.white24, size: 42),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1B1E2B),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF3A4059)),
      boxShadow: const [
        BoxShadow(color: Colors.black38, offset: Offset(0, 5), blurRadius: 12),
      ],
    ),
    child: child,
  );
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFFFFD58E)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
    ],
  );
}
