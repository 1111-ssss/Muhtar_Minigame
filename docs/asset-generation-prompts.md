# Пакет промптов для игровых картинок и спрайтов

Этот документ — полный план визуальных ассетов для **Muhtar Minigame**. В нём
указано, **для чего** нужен каждый файл, куда его положить и какой промпт
использовать при генерации.

Сейчас игра умеет работать с несколькими портретами, а персонажи, тайлы и
объекты мира в основном рисуются процедурно. Поэтому список разделён на две
части:

1. ассеты, которые можно подключить к уже существующим экранам без изменения
   игрового дизайна;
2. полноценные спрайты, атласы, тайлы и эффекты для следующего визуального
   этапа.

## Как пользоваться документом

Для каждого ассета:

1. сгенерируйте картинку по полю **Промпт**;
2. проверьте её по полю **Проверка**;
3. сохраните под точным именем из поля **Файл**;
4. положите в указанную папку;
5. не меняйте размер отдельной ячейки в атласе — код интеграции будет ожидать
   именно эти размеры.

Промпты написаны на английском: большинство генераторов точнее понимает
технические требования к pixel art на английском. Русское описание перед
каждым промптом объясняет, зачем нужна картинка.

## Общая художественная спецификация

- **Стиль:** современный hand-crafted pixel art для 2D изометрической RPG;
  читаемый силуэт, чёткие пиксели, без фотореализма и без 3D-render look.
- **Палитра:** тёмный сине-серый UI `#171923`, янтарный акцент `#FFC857`,
  бирюзовый акцент `#5BC0EB`, зелёные парковые тона, тёплый песок и серый
  камень Моста.
- **Свет:** мягкий свет сверху-слева, контрастный контур, предмет не должен
  сливаться с тёмным UI.
- **Фон:** для спрайтов и предметов — полностью прозрачный фон; для портретов
  допускается простой тематический фон, если он входит в композицию портрета.
- **Запрет:** никакого текста, букв, цифр, водяных знаков, случайных логотипов,
  лишних конечностей, обрезанных голов и предметов, выходящих за canvas.
- **Пиксельная дисциплина:** без сглаживания, без полуразмытых краёв, без
  тонких линий меньше одного пикселя в целевом размере.
- **Единый масштаб:** персонаж занимает примерно 70–85% высоты кадра, но не
  касается краёв; тень отделена от силуэта и не запекается в прозрачный фон.

## Форматы и размеры

| Группа | Формат | Размер | Фон |
|---|---|---:|---|
| Портреты диалогов и боя | PNG | 512×576 | простой фон или прозрачный |
| Малые world-спрайты | PNG | ячейка 64×64 | прозрачный |
| Крупные враги | PNG | ячейка 96×96 | прозрачный |
| Атлас персонажа | PNG | 4 направления × 4 кадра | прозрачный |
| Тайлы | PNG | ячейка 80×40 | прозрачный по углам |
| UI-иконки | PNG | 128×128 | прозрачный |
| Эффекты | PNG | ячейка 128×128 | прозрачный |
| Фон splash/title | PNG/WebP | 1280×720 | полноценная иллюстрация |

## Общий negative prompt

Добавляйте этот блок к каждому промпту, если генератор поддерживает negative
prompt:

> photorealistic, 3d render, smooth vector art, blurry pixels, anti-aliased
> edges, text, letters, numbers, logo, watermark, signature, UI frame, cropped
> subject, extra limbs, duplicate character, malformed hands, noisy background,
> gradient banding, low contrast silhouette, object cut off by the canvas

## Порядок генерации

### Пакет A — сразу подключаемые портреты

Сначала сгенерируйте портреты всех NPC и врагов. Это даст заметный визуальный
эффект в диалогах и бою, не требуя переделки карты.

### Пакет B — персонажи мира

Затем сделайте world-спрайты игрока, NPC и врагов в одинаковых атласах. Они
заменят процедурные фигурки в `lib/game/world/map_entity.dart`.

### Пакет C — окружение и карты

После персонажей создайте тайлы, деревья, камни, мебель, здания и декор. Это
самый большой пакет: его лучше генерировать сериями с одной контрольной
картинкой масштаба.

### Пакет D — бой, предметы и эффекты

В конце создайте атласы костей, экипировки, артефактов, наград и эффектов.

---

# 1. Портреты персонажей

Все эти файлы должны иметь вертикальную композицию 512×576. Взгляд персонажа
направляйте немного в сторону зрителя, оставляйте свободное место вокруг лица,
чтобы `BoxFit.cover` не обрезал глаза и головной убор.

## 1.1 Игрок и наградный скин

### `muhtar_minigame/assets/portraits/player.png`

**Для чего:** основной портрет Буберчика в бою, HUD и экранах прогресса.

**Промпт:**

> Vertical 512x576 pixel-art RPG portrait of Buberchik, a funny young courier
> hero with a confident but slightly confused expression, short dark hair,
> oversized yellow-orange hoodie, small delivery shoulder bag, simple warm skin
> tone, amber and teal rim light, dark blue-gray urban background with tiny
> abstract station lights, centered bust, bold readable silhouette, detailed
> face, hand-crafted 16-bit pixel art, crisp pixel clusters, no text, transparent
> outer edges around the character

**Проверка:** лицо и жёлтая толстовка читаются в маленькой рамке; нет телефона,
оружия или случайного логотипа.

### `muhtar_minigame/assets/portraits/player_ribka_reward.png`

**Для чего:** портрет наградного скина Рибки из задания `q_song`.

**Промпт:**

> Vertical 512x576 pixel-art RPG portrait of a cheerful young woman named
> Ribka, turquoise jacket, coral scarf, long dark teal hair, playful friendly
> smile, small musical charm on the scarf, aquatic cyan and warm coral accents,
> subtle dark bridge-and-water background, centered bust, expressive eyes,
> hand-crafted 16-bit pixel art, crisp unblurred pixels, clean silhouette, no
> text, no logo, no watermark

**Проверка:** Рибка отличается от обычного игрока цветами бирюза + коралл, но
выглядит частью той же игры.

## 1.2 NPC для диалогов

### `muhtar_minigame/assets/portraits/ariana.png`

**Для чего:** портрет Арианы на Вокзале; первый сюжетный контакт и магазин
костей.

**Промпт:**

> Vertical 512x576 pixel-art portrait of Ariana, a sharp and reliable young
> woman who works at a city railway station, dark bob haircut, mustard jacket,
> teal messenger scarf, clipboard held low and mostly outside the crop,
> welcoming but businesslike expression, warm station lamps behind her, amber
> and teal palette, centered bust, readable face at thumbnail size, hand-crafted
> 16-bit pixel art, crisp pixels, no text or logos

**Проверка:** персонаж должен выглядеть как диспетчер/работодатель, а не как
воин или продавец в фэнтези-магазине.

### `muhtar_minigame/assets/sofia.png`

**Для чего:** портрет Софии в Парке; короткий странный диалог и визуальный
контраст с другими NPC.

**Промпт:**

> Vertical 512x576 pixel-art RPG portrait of Sofia, an aloof eccentric teenage
> girl with a completely white oversized outfit, pale blond hair, square dark
> glasses, tiny golden accessory, unimpressed expression, surreal fanfic-writer
> energy, minimal pale background with faint park foliage, white clothing must
> remain readable against a muted blue-gray background, centered bust, crisp
> 16-bit pixel art, no text, no watermark

**Проверка:** белый костюм не должен сливаться с фоном; очки и холодное
выражение лица обязательны.

### `muhtar_minigame/assets/ribka.png`

**Для чего:** портрет NPC Рибки на Мосту и экран мини-игры с песней.

**Промпт:**

> Vertical 512x576 pixel-art RPG portrait of Ribka, a lively bridge-side girl
> with long dark teal hair, turquoise hoodie, coral scarf, small music-note
> hair clip, bright curious smile, blue water and gray bridge railing in the
> background, cyan and coral highlights, centered bust, expressive eyes, clean
> 16-bit pixel clusters, no musical notation text, no logo, no watermark

**Проверка:** портрет должен совпадать по внешности с наградным скином, но быть
более разговорным и светлым.

### `muhtar_minigame/assets/baba_galya.png`

**Для чего:** портрет Бабы Гали в Чебуречной, магазин и задание на шоколадку.

**Промпт:**

> Vertical 512x576 pixel-art RPG portrait of Baba Galya, a warm older woman
> running a tiny cheburek diner, patterned headscarf, red-brown apron, kind
> tired eyes, flour mark on one cheek, proud welcoming smile, cozy stainless
> kitchen and warm orange lamp in the background, centered bust, handmade 16-bit
> pixel art, strong silhouette, no readable food labels, no text, no watermark

**Проверка:** должна ощущаться хозяйка маленькой столовой; не добавлять повара
в высокой шефской шапке.

### `muhtar_minigame/assets/alenka.png`

**Для чего:** портрет Алёнки в Копеечке и интерфейс магазина.

**Промпт:**

> Vertical 512x576 pixel-art RPG portrait of Alenka, a cheerful convenience
> store clerk, neat chestnut ponytail, lavender-and-cream uniform, bright
> attentive smile, small barcode scanner kept outside the crop, shelves of
> colorful generic chocolate bars softly blurred behind her, violet and amber
> accents, centered bust, crisp 16-bit pixel art, packages have no readable
> brand names, no text, no watermark

**Проверка:** не использовать настоящие логотипы шоколада; упаковки только
абстрактные цветовые пятна.

### `muhtar_minigame/assets/malek.png`

**Для чего:** портрет Малёка в Копеечке; задание на поиск SyncAsync.

**Промпт:**

> Vertical 512x576 pixel-art RPG portrait of Malek, a quirky older shop worker
> with a navy baseball cap, short beard, blue work jacket, small golden walking
> cane visible at the lower edge, suspicious but hopeful expression, convenience
> store aisle behind him, navy, gold and muted teal palette, centered bust,
> hand-crafted 16-bit pixel art, crisp pixels, no text, no watermark

**Проверка:** кепка, борода и золотистая трость должны совпадать с процедурным
силуэтом NPC в мире.

### `muhtar_minigame/assets/buber.png`

**Для чего:** портрет Бубера для диалога в Колледже.

**Промпт:**

> Vertical 512x576 pixel-art RPG portrait of Buber, a smug teenage college
> student with an exaggerated confident grin, dark short hair, purple school
> jacket with a gold trim, slightly raised eyebrow, cheap backpack strap, muted
> college corridor behind him, purple, gold and dark navy palette, centered bust,
> readable expression at small size, crisp 16-bit pixel art, no text, no logo

**Проверка:** самоуверенность должна быть комичной, без агрессивного оружия или
реалистичной школьной формы с логотипом.

## 1.3 Портреты врагов

### `muhtar_minigame/assets/portraits/gopnik.png`

**Для чего:** портрет рядового Гопника в бою.

**Промпт:**

> Vertical 512x576 pixel-art RPG enemy portrait of a street gopnik, stocky
> young man in a blue tracksuit, flat cap, red shoulder bag, bored hostile
> stare, hands outside the crop, green park and concrete path behind him, strong
> blue and red accents, chunky readable silhouette, hand-crafted 16-bit pixel
> art, no weapon, no text, no watermark

**Проверка:** должен быть узнаваемый городской хулиган, а не фэнтезийный
разбойник.

### `muhtar_minigame/assets/portraits/shaurmek.png`

**Для чего:** портрет Шаурмека — огненного врага и сюжетной цели в Копеечке.

**Промпт:**

> Vertical 512x576 pixel-art RPG enemy portrait of Shaurmek, a fast-talking
> shawarma vendor with warm olive skin, dark curly hair, brown apron, one hand
> holding a generic wrapped street-food roll outside the face crop, orange-red
> hot sauce accent, smoky convenience-store kitchen background, mischievous
> threatening smile, warm red and gold lighting, crisp 16-bit pixel art, no
> readable brand, no text, no watermark

**Проверка:** еда не должна закрывать лицо; использовать выдуманный нейтральный
образ без реального логотипа.

### `muhtar_minigame/assets/portraits/viktor_korneplod.png`

**Для чего:** портрет Виктора Корнеплода — сильного сюжетного босса.

**Промпт:**

> Vertical 512x576 pixel-art RPG enemy portrait of Viktor Korneplod, a broad
> eccentric root-vegetable guardian with bark-like shoulder armor, moss-green
> coat, orange-brown root-shaped beard, stern proud face, faint roots and stone
> tiles behind him, green, brown and amber palette, large imposing silhouette,
> hand-crafted 16-bit pixel art, no gore, no text, no watermark

**Проверка:** образ должен быть фантазийным и растительным, но оставаться
персонажем, а не просто овощем.

### `muhtar_minigame/assets/portraits/slime.png`

**Для чего:** резервный портрет Слизня для будущих боёв и расширения контента.

**Промпт:**

> Vertical 512x576 pixel-art RPG enemy portrait of a friendly-looking but
> dangerous lime-green slime, translucent body with two square highlights and
> tiny dark eyes, ember-orange glow inside, dark neutral battle background,
> centered silhouette, readable at thumbnail size, crisp 16-bit pixel art, no
> text, no watermark

**Проверка:** прозрачность должна читаться через два-три оттенка зелёного, без
реалистичной жидкой текстуры.

### `muhtar_minigame/assets/portraits/goblin.png`

**Для чего:** резервный портрет Гоблина для будущих боёв.

**Промпт:**

> Vertical 512x576 pixel-art RPG enemy portrait of a short purple-armored
> goblin, pointed ears, oversized expressive eyes, crooked club kept outside the
> crop, mischievous grin, dark forest edge background, violet, green and amber
> palette, chunky readable silhouette, hand-crafted 16-bit pixel art, no text,
> no watermark

**Проверка:** клуб не должен выглядеть как современное оружие; силуэт должен
отличаться от Гопника.

---

# 2. Спрайты персонажей мира

Эти ассеты предназначены для замены процедурных фигурок на карте. Для каждого
персонажа генерируйте один атлас `256×256`: 4 строки направлений и 4 столбца
кадров.

Порядок строк во всех атласах одинаковый:

1. вниз / к камере;
2. влево;
3. вправо;
4. вверх / от камеры.

В каждом ряду кадры такие: `idle`, шаг 1, `idle`, шаг 2. Нижняя точка ног
должна находиться на одной горизонтальной линии во всех 16 кадрах. Если
генератор плохо держит сетку, сначала создайте один кадр-референс, а потом
сделайте image-to-image по четырём направлениям.

## 2.1 Игрок

### `muhtar_minigame/assets/sprites/characters/player.png`

**Для чего:** основной персонаж на изометрической карте; движение, остановка и
анимация шага.

**Промпт:**

> Pixel-art character sprite sheet, 4 rows by 4 columns, each cell exactly 64x64,
> transparent background. Buberchik, a funny young courier hero in a yellow
> orange hoodie, dark trousers, small delivery shoulder bag, short dark hair.
> Row 1 faces camera, row 2 faces left, row 3 faces right, row 4 faces away.
> Frames are idle, left foot forward, idle, right foot forward. Full body in
> every cell, feet aligned to the same baseline, compact readable silhouette,
> warm amber and teal accents, hand-crafted 16-bit pixel art, no shadows outside
> the feet, no text, no border, no watermark.

**Проверка:** все 16 кадров находятся в сетке, персонаж не прыгает по высоте,
сумка остаётся на одном плече.

### `muhtar_minigame/assets/sprites/characters/player_ribka_reward.png`

**Для чего:** альтернативный world-скин после задания Рибки.

**Промпт:**

> Pixel-art character sprite sheet, 4 rows by 4 columns, each cell exactly 64x64,
> transparent background. Ribka reward skin: young woman with long dark teal
> hair, turquoise jacket, coral scarf, dark trousers and a small musical charm.
> Row 1 faces camera, row 2 faces left, row 3 faces right, row 4 faces away.
> Four walk-cycle frames per direction: idle, left step, idle, right step.
> Consistent feet baseline, hair and scarf move by only one or two pixels between
> frames, crisp 16-bit pixel art, no text, no logo, no watermark.

**Проверка:** этот спрайт должен быть тем же персонажем, что и портрет
`player_ribka_reward.png`.

## 2.2 NPC

### `muhtar_minigame/assets/sprites/characters/ariana.png`

**Для чего:** world-спрайт Арианы на Вокзале.

**Промпт:**

> Pixel-art 4x4 character sprite sheet, each cell 64x64, transparent background.
> Ariana, a railway-station coordinator with dark bob haircut, mustard jacket,
> teal messenger scarf and clipboard tucked to her side. Four directions, four
> subtle idle and walking frames per direction, feet aligned, readable amber and
> teal silhouette, 16-bit pixel art, no text or logo.

### `muhtar_minigame/assets/sprites/characters/sofia.png`

**Для чего:** world-спрайт Софии в Парке.

**Промпт:**

> Pixel-art 4x4 character sprite sheet, each cell 64x64, transparent background.
> Sofia, an aloof eccentric girl in a bright white oversized outfit, pale blond
> hair and square dark glasses. Four directions, four subtle walking frames,
> strong dark outline so the white clothes remain visible, 16-bit pixel art,
> consistent feet baseline, no text, no logo.

### `muhtar_minigame/assets/sprites/characters/ribka.png`

**Для чего:** world-спрайт Рибки на Мосту.

**Промпт:**

> Pixel-art 4x4 character sprite sheet, each cell 64x64, transparent background.
> Ribka with long dark teal hair, turquoise hoodie, coral scarf and a tiny music
> charm. Four directions, idle and two-step walking cycle, scarf moves subtly,
> feet aligned to a fixed baseline, bright cyan and coral accents, crisp 16-bit
> pixel art, no text, no watermark.

### `muhtar_minigame/assets/sprites/characters/baba_galya.png`

**Для чего:** world-спрайт Бабы Гали в Чебуречной.

**Промпт:**

> Pixel-art 4x4 character sprite sheet, each cell 64x64, transparent background.
> Baba Galya, older diner owner in a patterned headscarf and red-brown apron,
> warm round silhouette, one hand carrying a tiny serving tray. Four directions,
> four idle and walking frames, readable apron shape, crisp 16-bit pixel art,
> no text, no brand, no watermark.

### `muhtar_minigame/assets/sprites/characters/alenka.png`

**Для чего:** world-спрайт Алёнки в Копеечке.

**Промпт:**

> Pixel-art 4x4 character sprite sheet, each cell 64x64, transparent background.
> Alenka, cheerful convenience-store clerk with chestnut ponytail, lavender and
> cream uniform, small scanner in one hand. Four directions, four walking frames,
> compact readable silhouette, violet and amber accents, hand-crafted 16-bit
> pixel art, no text or logo.

### `muhtar_minigame/assets/sprites/characters/malek.png`

**Для чего:** world-спрайт Малёка с узнаваемой кепкой и тростью.

**Промпт:**

> Pixel-art 4x4 character sprite sheet, each cell 64x64, transparent background.
> Malek, quirky older shop worker wearing a navy baseball cap and blue work
> jacket, holding a slim golden walking cane. Four directions, four idle and
> walking frames, cane remains visible without crossing the neighboring cell,
> crisp 16-bit pixel art, no text, no watermark.

### `muhtar_minigame/assets/sprites/characters/buber.png`

**Для чего:** world-спрайт Бубера в Колледже.

**Промпт:**

> Pixel-art 4x4 character sprite sheet, each cell 64x64, transparent background.
> Buber, smug teenage college student in a purple jacket with gold trim and a
> small backpack. Four directions, four subtle walking frames, exaggerated
> confident posture without combat weapon, crisp 16-bit pixel art, no text, no
> school logo, no watermark.

## 2.3 Враги

### `muhtar_minigame/assets/sprites/characters/gopnik.png`

**Для чего:** world-спрайт Гопника в Парке.

**Промпт:**

> Pixel-art 4x4 enemy sprite sheet, each cell 64x64, transparent background.
> Stocky street gopnik in a blue tracksuit, flat cap and red shoulder bag.
> Four directions, idle and two-step walking frames, aggressive hunched posture,
> chunky readable silhouette, no weapon, crisp 16-bit pixel art, no text, no
> watermark.

### `muhtar_minigame/assets/sprites/characters/shaurmek.png`

**Для чего:** world-спрайт Шаурмека в Копеечке.

**Промпт:**

> Pixel-art 4x4 enemy sprite sheet, each cell 64x64, transparent background.
> Shaurmek, fast-talking shawarma vendor in a brown apron, dark curly hair,
> orange-red sauce accent and a generic wrapped food roll held low. Four
> directions, idle and walking frames, warm red and gold details, no readable
> packaging, crisp 16-bit pixel art, no text, no watermark.

### `muhtar_minigame/assets/sprites/characters/viktor_korneplod.png`

**Для чего:** крупный world-спрайт Виктора Корнеплода.

**Промпт:**

> Pixel-art 4x4 large enemy sprite sheet, each cell 96x96, transparent
> background. Viktor Korneplod, broad root-vegetable guardian with bark-like
> shoulder armor, moss-green coat and orange-brown root beard. Four directions,
> powerful idle and slow walking frames, feet aligned, roots never touch the
> cell border, hand-crafted 16-bit pixel art, no gore, no text, no watermark.

### `muhtar_minigame/assets/sprites/characters/slime.png`

**Для чего:** резервный world-спрайт Слизня для будущих карт.

**Промпт:**

> Pixel-art 4x4 enemy sprite sheet, each cell 64x64, transparent background.
> Lime-green translucent slime with square highlights and tiny dark eyes, four
> directions represented by slight facing changes, idle wobble and two bounce
> frames, crisp 16-bit pixel art, no text, no watermark.

### `muhtar_minigame/assets/sprites/characters/goblin.png`

**Для чего:** резервный world-спрайт Гоблина для будущих карт.

**Промпт:**

> Pixel-art 4x4 enemy sprite sheet, each cell 64x64, transparent background.
> Short purple-armored goblin with pointed ears and a crooked wooden club held
> low, four directions, idle and small walking frames, readable silhouette,
> crisp 16-bit pixel art, no modern weapon, no text, no watermark.

---

# 3. Тайлы, здания и окружение

## 3.1 Базовый набор тайлов

### `muhtar_minigame/assets/sprites/tiles/terrain_atlas.png`

**Для чего:** единый атлас для всех клеток изометрических карт. Он заменит
процедурно нарисованные ромбы в `IsometricMap`.

**Промпт:**

> A single horizontal pixel-art tile atlas with exactly 15 diamond-shaped
> isometric tiles, each tile exactly 80x40, total canvas 1200x40, transparent
> corners and identical diamond geometry. Keep this exact left-to-right order:
> 0 warm grass, 1 dark wall, 2 worn road, 3 forest edge, 4 blue teleport
> portal, 5 fully transparent empty tile, 6 blue-green water, 7 raised gray
> bridge edge, 8 railway ballast with two rails, 9 warm dirt, 10 gray stone
> paving, 11 wooden planks, 12 pale sand, 13 flower meadow, 14 gravel. Hand-made
> 16-bit pixel art, crisp one-pixel outline, restrained texture, no text, no
> extra tiles, no grid lines between cells.

**Проверка:** canvas ровно 1200×40; в прозрачном тайле нет случайной заливки;
все ромбы имеют одинаковую высоту и ширину.

### `muhtar_minigame/assets/sprites/tiles/terrain_variants_atlas.png`

**Для чего:** дополнительные варианты земли, дороги и травы, чтобы большие
карты не выглядели повторяющимся узором.

**Промпт:**

> Pixel-art isometric terrain variant atlas, 12 separate 80x40 diamond tiles on
> a transparent 960x40 canvas: three warm grass variants, three dirt variants,
> two worn road variants, two flower meadow variants, one gravel variant and one
> stone variant. Same diamond geometry as a classic 80x40 isometric tile, subtle
> clustered pixels, no obvious repeating symbol, no text, no grid lines, crisp
> 16-bit pixel art.

**Проверка:** варианты должны комбинироваться с основным terrain atlas без
изменения угла ромба и масштаба.

### `muhtar_minigame/assets/sprites/tiles/bridge_edges_atlas.png`

**Для чего:** серые поднятые края Моста, банки и переходы к воде.

**Промпт:**

> Pixel-art isometric bridge edge atlas with 8 cells of 80x40 and transparent
> corners: straight raised gray edge, left end, right end, upper corner, lower
> corner, chipped edge, mossy edge and portal edge. Weathered gray stone and
> concrete, muted blue-gray palette, each cell shares the same 80x40 diamond
> footprint, crisp 16-bit pixels, no text, no grid lines.

**Проверка:** край должен визуально быть выше деревянного настила, но не
закрывать соседние клетки.

### `muhtar_minigame/assets/sprites/tiles/water_atlas.png`

**Для чего:** вода вокруг Моста и декоративные анимации поверхности.

**Промпт:**

> Pixel-art isometric water atlas, 6 frames of the same 80x40 diamond tile,
> blue-green river water with two or three bright horizontal ripples moving one
> pixel per frame, transparent corners, calm readable pattern, no foam text,
> no grid lines, crisp 16-bit pixel art, seamless-looking adjacent edges.

**Проверка:** кадры не должны менять базовый цвет и границы воды; анимация очень
медленная и не отвлекает от персонажа.

## 3.2 Вокзал и Парк

### `muhtar_minigame/assets/sprites/props/station_sign.png`

**Для чего:** главный визуальный ориентир стартовой локации Вокзал.

**Промпт:**

> Isometric pixel-art world prop, transparent background, a small old railway
> station sign on two metal posts, teal and cream signboard with a completely
> abstract unreadable mark, warm yellow lamp, 96x128 canvas, front three-quarter
> view matching an 80x40 isometric game, crisp 16-bit pixels, no letters, no
> numbers, no watermark.

### `muhtar_minigame/assets/sprites/props/station_bench.png`

**Для чего:** лавочка на платформе Вокзала и интерактивный декоративный объект.

**Промпт:**

> Isometric pixel-art prop, transparent background, worn wooden railway bench
> with two dark metal legs, warm brown planks, tiny chipped paint details,
> 128x80 canvas, readable silhouette from the game camera, crisp 16-bit pixels,
> no person, no text, no watermark.

### `muhtar_minigame/assets/sprites/props/railway_lamp.png`

**Для чего:** вертикальный светильник для Вокзала и позднего вечернего варианта
карты.

**Промпт:**

> Isometric pixel-art railway lamp prop, transparent background, thin dark metal
> post, small warm amber lantern, subtle two-pixel glow only inside the sprite,
> 64x128 canvas, strong silhouette, crisp 16-bit pixel art, no text, no logo.

### `muhtar_minigame/assets/sprites/props/park_tree_set.png`

**Для чего:** три варианта деревьев Парка, Вокзала и площадки Коня.

**Промпт:**

> Pixel-art prop atlas with 4 separate tree sprites on a transparent 384x192
> canvas: young round tree, tall narrow tree, broad leafy tree, autumn-tinted
> tree. Each sprite fits a 96x128 cell, dark readable trunk, layered green
> foliage with amber highlights, no repeated identical clusters, crisp 16-bit
> pixel art, no text, no background.

### `muhtar_minigame/assets/sprites/props/park_bush_set.png`

**Для чего:** обычные кусты и поисковые кусты Парка.

**Промпт:**

> Pixel-art prop atlas with 4 separate bush sprites on a transparent 256x128
> canvas: ordinary green bush, flowering bush, dense searchable bush with a tiny
> glint hidden inside, and empty trampled bush. Each cell 64x64, soft dark
> outline, green leaves with two highlight tones, no visible icon or text, crisp
> 16-bit pixel art.

### `muhtar_minigame/assets/sprites/props/park_rock_set.png`

**Для чего:** камни Парка и Вокзала, чтобы окружение не состояло только из
деревьев.

**Промпт:**

> Pixel-art prop atlas with 5 gray and brown rock shapes, transparent background,
> each rock inside a 64x48 cell, irregular but readable silhouettes, one small
> moss highlight per rock, top-left light, crisp 16-bit pixels, no text, no
> background.

### `muhtar_minigame/assets/sprites/props/park_log.png`

**Для чего:** крупный декоративный объект в Парке и дополнительная точка
ориентира.

**Промпт:**

> Isometric pixel-art fallen log prop, transparent background, mossy brown trunk
> lying diagonally across one or two ground cells, visible cut end with two rings,
> a few tiny mushrooms, 128x80 canvas, crisp 16-bit pixels, no text, no
> characters, no watermark.

## 3.3 Мост и площадка «Конь»

### `muhtar_minigame/assets/sprites/props/bridge_plank_set.png`

**Для чего:** набор деревянных секций настила Моста, который должен выглядеть
живее, чем один повторяющийся тайл.

**Промпт:**

> Pixel-art isometric bridge plank prop atlas, transparent background, 6 pieces:
> straight plank deck, cracked plank, patched plank, short side beam, rope knot
> and small nail detail. Each piece fits an 80x40 diamond cell, dark brown wood,
> pale worn top edges, gray metal fasteners, crisp 16-bit pixel art, no text, no
> grid lines.

### `muhtar_minigame/assets/sprites/props/bridge_railing_set.png`

**Для чего:** перила, стойки и обломанные секции по краям Моста.

**Промпт:**

> Pixel-art isometric bridge railing atlas with 6 transparent pieces: straight
> gray railing, short railing, broken railing, corner post, rope repair and
> warning post with a blank amber marker. Match an 80x40 diamond grid, weathered
> gray metal, dark outlines, crisp 16-bit pixels, no letters, no numbers, no
> watermark.

### `muhtar_minigame/assets/sprites/props/reeds_set.png`

**Для чего:** растительность на берегах вокруг Моста.

**Промпт:**

> Pixel-art prop atlas with 5 small river reed clumps on transparent background,
> each in a 48x64 cell, blue-green and ochre reeds bending in slightly different
> directions, a few pale seed heads, readable at game zoom, crisp 16-bit pixels,
> no text, no background.

### `muhtar_minigame/assets/sprites/props/fishing_spot.png`

**Для чего:** декоративная точка у Рибки на Мосту; можно использовать как
будущий интерактивный объект.

**Промпт:**

> Isometric pixel-art fishing spot prop, transparent background, small wooden
> crate, coiled rope, short fishing rod leaning against it and one blue-green
> bucket, 128x96 canvas, muted bridge-side palette, clear silhouette, crisp
> 16-bit pixel art, no fish text, no logo, no watermark.

### `muhtar_minigame/assets/sprites/props/horse_portal_set.png`

**Для чего:** четыре разные точки выхода на площадке «Конь»: Мост, Донер,
Колледж, Общага и ВБ. Один атлас позволяет различать направления без текста.

**Промпт:**

> Pixel-art portal marker atlas with 5 separate transparent isometric props,
> each inside a 96x96 cell: bridge marker with gray stone and cyan glow, diner
> marker with warm orange awning, college marker with purple book emblem,
> dormitory marker with blue window emblem, parcel pickup marker with violet
> package emblem. No readable letters, no numbers, no real logos, all markers
> share the same compact 16-bit style and amber outline.

### `muhtar_minigame/assets/sprites/props/portal_glow.png`

**Для чего:** анимируемое свечение клетки телепорта поверх любого портала.

**Промпт:**

> Pixel-art VFX sprite sheet, 6 frames in one row, each cell 80x40 with
> transparent corners, a cool blue teleport rune glow forming and fading over an
> isometric diamond, tiny cyan particles, no text, no symbol that resembles a
> letter, crisp 16-bit pixels, identical footprint in every frame.

## 3.4 Интерьеры и здания

### `muhtar_minigame/assets/sprites/buildings/station_platform.png`

**Для чего:** крупный декоративный задник платформы Вокзала, если карта будет
расширена до полноценной станции.

**Промпт:**

> Wide isometric pixel-art environment strip for a small city railway station:
> platform edge, two rails, low canopy, amber lamps, ticket booth silhouette,
> scattered luggage, no people, no readable signs, transparent background where
> possible, designed to tile horizontally across a 1280x320 game area, muted
> brown, teal and amber palette, crisp 16-bit pixels.

### `muhtar_minigame/assets/sprites/buildings/doner_exterior.png`

**Для чего:** внешний фасад Донера рядом с Мостом.

**Промпт:**

> Isometric pixel-art small street-food diner facade, transparent background,
> rounded orange awning, warm window, generic wrapped-food pictogram with no
> letters, compact doorway and one outdoor trash bin, 256x192 canvas, dark teal
> shadows, warm orange light, crisp 16-bit game art, no real brand logo, no text.

### `muhtar_minigame/assets/sprites/buildings/kopeechka_exterior.png`

**Для чего:** вход в Копеечку на правом берегу Моста.

**Промпт:**

> Isometric pixel-art neighborhood convenience-store facade, transparent
> background, cool gray-blue wall, violet and amber shop lights, abstract shelf
> shapes visible through the window, blank sign panel with no letters, compact
> entrance, 256x192 canvas, crisp 16-bit pixels, no real logo, no watermark.

### `muhtar_minigame/assets/sprites/buildings/cheburechnaya_exterior.png`

**Для чего:** вход в Чебуречную рядом с Копеечкой.

**Промпт:**

> Isometric pixel-art tiny cheburek diner facade, transparent background, warm
> brown and red awning, steamy serving window, generic pastry silhouette with no
> readable sign, small flower pot, 256x192 canvas, cozy amber lighting, crisp
> 16-bit pixel art, no real logo, no text, no watermark.

### `muhtar_minigame/assets/sprites/buildings/college_gate.png`

**Для чего:** узнаваемый объект на площадке Колледжа.

**Промпт:**

> Isometric pixel-art college entrance gate, transparent background, low gray
> brick facade, purple banner with an entirely abstract emblem, two warm lamps,
> narrow doorway and a few steps, 256x192 canvas, clean readable silhouette,
> crisp 16-bit pixels, no letters, no school logo, no watermark.

### `muhtar_minigame/assets/sprites/buildings/dormitory_block.png`

**Для чего:** фасад Общаги и ориентир на маленькой карте.

**Промпт:**

> Isometric pixel-art dormitory entrance, transparent background, compact pale
> concrete building section, three blue-lit windows, dark blue door, two bicycles
> and a small notice board with no readable text, 256x192 canvas, evening amber
> and cyan lighting, crisp 16-bit pixel art, no letters, no logo, no watermark.

### `muhtar_minigame/assets/sprites/buildings/wb_pickup_point.png`

**Для чего:** фасад пункта выдачи посылок на карте ВБ.

**Промпт:**

> Isometric pixel-art parcel pickup point, transparent background, violet and
> white facade, stacked generic cardboard parcels, simple glowing package icon,
> narrow entrance and a small bench, 256x192 canvas, no real company logo, no
> readable text, crisp 16-bit pixels, strong silhouette, no watermark.

### `muhtar_minigame/assets/sprites/buildings/shop_interior_tiles.png`

**Для чего:** фоновые стены, полки, стойки и пол для интерьеров Копеечки,
Чебуречной и Донера.

**Промпт:**

> Pixel-art interior prop atlas with 12 transparent or tileable pieces: gray
> shop wall, warm diner wall, wooden counter, metal shelf, generic product box,
> refrigerator, small table, stool, serving window, hanging lamp, floor mat and
> trash bin. Isometric 80x40-compatible geometry, muted dark UI-friendly palette,
> crisp 16-bit pixel art, no readable packaging, no letters, no logos.

---

# 4. Бой, кости, предметы и UI

## 4.1 Атлас костей

### `muhtar_minigame/assets/sprites/items/dice_atlas.png`

**Для чего:** изображения пяти типов костей из `GameContent.diceCatalog`:
`blade`, `doctor`, `ember`, `guardian`, `upgrade`. Атлас используется в
инвентаре, хотбаре, на доске и в кейсах.

**Промпт:**

> Pixel-art dice atlas on a transparent 640x160 canvas, exactly 5 large square
> dice arranged left to right, each 128x128 with 8 pixels of clear spacing:
> warrior blade die with amber sword mark, doctor die with mint medical cross,
> ember die with orange flame, guardian die with blue shield, upgrade die with
> violet upward arrows. Slight bevel, readable dark pips, no letters, no numbers
> except six clean pip layouts in a separate second atlas, no logos, crisp 16-bit
> pixel art, strong contrast against a dark navy UI.

**Проверка:** каждая кость имеет уникальный силуэт/цвет; символ расположен по
центру и не касается границы.

### `muhtar_minigame/assets/sprites/items/dice_faces_atlas.png`

**Для чего:** шесть граней каждой кости с корректными значениями 1–6. Нужен
отдельный атлас, чтобы число можно было менять без генерации новой картинки.

**Промпт:**

> Pixel-art dice face atlas with 5 rows and 6 columns, each cell exactly 64x64,
> transparent background. Rows are warrior amber, doctor mint, ember orange,
> guardian blue, upgrade violet; columns are clean pip values one through six.
> Keep identical rounded-square die silhouette, centered pips, subtle ability
> color border, no written numerals, no text, crisp 16-bit pixel art, exact grid,
> no shadows outside cells.

**Проверка:** пипсы должны быть различимы на экране 32–48 px; порядок строк и
столбцов нельзя менять.

## 4.2 Экипировка и артефакты

### `muhtar_minigame/assets/sprites/items/equipment_atlas.png`

**Для чего:** иконки стартовой экипировки: меч, щит и зелье.

**Промпт:**

> Pixel-art item icon atlas, 3 separate 128x128 transparent cells: short steel
> sword with amber edge, compact blue-gray shield with a gold rim, small green
> healing potion in a glass bottle with a red cork. Front-facing readable icons,
> thick dark outline, crisp 16-bit pixels, no text, no logo, no watermark.

### `muhtar_minigame/assets/sprites/items/artifact_atlas.png`

**Для чего:** иконки шести артефактов: печать перемирия, железная нить,
точильный камень, полевой набор, сердце угля и счастливый амулет.

**Промпт:**

> Pixel-art artifact icon atlas, 6 separate 128x128 transparent cells with equal
> spacing: truce seal as a purple wax seal, iron thread as a silver spool,
> whetstone as a blue-gray sharpening stone, field kit as a mint medical pouch,
> ember heart as a glowing orange crystal heart, lucky charm as a small gold
> loop charm. Dark violet item shadows, warm highlights, crisp 16-bit pixels, no
> letters, no symbols resembling text, no watermark.

### `muhtar_minigame/assets/sprites/items/case_atlas.png`

**Для чего:** кейсы костей и артефактов в инвентаре и анимации открытия.

**Промпт:**

> Pixel-art reward case atlas with 4 separate 128x128 transparent cells: closed
> wooden dice case, closed metal dice case, closed purple artifact case, open
> glowing reward case with light spilling upward. Same perspective and outline,
> amber, teal and violet accents, crisp 16-bit pixels, no text, no logo, no
> watermark.

### `muhtar_minigame/assets/sprites/items/shop_items_atlas.png`

**Для чего:** товары магазинов: чебурек, шоколадный батончик, абстрактный
шоколадный подарок и газировка. Использовать в карточках магазина и заданиях.

**Промпт:**

> Pixel-art shop item atlas with 4 separate 128x128 transparent cells: hot
> cheburek in a paper sleeve, generic blue-and-gold chocolate bar with no brand
> label, premium dark-gold chocolate bar with no readable text, red-black soda
> bottle with a completely abstract label. Cozy amber highlights, dark outline,
> crisp 16-bit pixel art, no real trademarks, no letters, no watermark.

## 4.3 UI-рамки и экраны

### `muhtar_minigame/assets/sprites/ui/panel_atlas.png`

**Для чего:** панели HUD, диалоги, магазин, журнал заданий и настройки. Атлас
должен поддерживать 9-slice, чтобы панели не растягивали угловые пиксели.

**Промпт:**

> Pixel-art UI 9-slice atlas on a transparent canvas: dark blue-gray panel,
> hover panel, amber selected panel, warning panel and violet reward panel. Each
> panel has four crisp corners, 2-pixel inner border and a flat stretchable
> center, no text, no icons, no gradients, no rounded modern glassmorphism,
> hand-crafted 16-bit game interface.

### `muhtar_minigame/assets/sprites/ui/button_atlas.png`

**Для чего:** кнопки выбора диалога, магазина, подтверждения и закрытия окон.

**Промпт:**

> Pixel-art UI button 9-slice atlas with normal, hover, pressed, disabled and
> dangerous-confirm states. Dark navy base, amber focus border, teal secondary
> accent, chunky 2-pixel edges, transparent outside, center must be stretchable,
> no text and no symbols, crisp 16-bit pixels, accessible strong contrast.

### `muhtar_minigame/assets/sprites/ui/quest_badges.png`

**Для чего:** маленькие значки типов заданий: локация, победа над врагом,
сбор монет, доставка предмета и мини-игра.

**Промпт:**

> Pixel-art quest badge atlas with 5 separate 96x96 transparent icons: winding
> road to a bridge, crossed sword, three gold coins, parcel with a check mark,
> and musical note puzzle. Use amber, teal, red and violet accents, no letters,
> no numbers, no watermark, crisp 16-bit pixels.

### `muhtar_minigame/assets/sprites/ui/hud_icons.png`

**Для чего:** иконки HP, монет, опыта, реролла, звука, настроек, инвентаря и
квестов в HUD.

**Промпт:**

> Pixel-art HUD icon atlas with 10 separate 64x64 transparent cells: heart,
> coin, star XP, circular reroll arrow, speaker, gear, backpack, quest scroll,
> map portal and pause symbol. Each icon has a dark outline and one strong accent
> color, readable at 24 pixels, no text, no numbers, crisp 16-bit pixel art.

### `muhtar_minigame/assets/sprites/ui/title_badges.png`

**Для чего:** бейджи названий локаций в переходе и маленькие маркеры названий
карт.

**Промпт:**

> Pixel-art title badge atlas with 4 blank horizontal nameplates: station amber,
> park green, bridge gray-blue and city violet. Each plate has a dark navy fill,
> crisp amber or teal border, subtle pixel shadow, transparent outside, wide
> center area for runtime text, no pre-rendered letters, no watermark.

---

# 5. Эффекты, анимации и переходы

Каждый эффект — отдельный sprite sheet в один ряд из 6–8 кадров. Фон всегда
прозрачный, а край эффекта не должен быть обрезан. Кадры должны идти слева
направо от появления к исчезновению.

### `muhtar_minigame/assets/sprites/fx/teleport_fx.png`

**Для чего:** визуальный эффект входа и выхода из телепорта в момент смены
локации.

**Промпт:**

> Pixel-art teleport VFX sprite sheet, 8 frames in one row, each cell 128x128,
> transparent background. A cyan and amber ring of square particles expands
> from a small isometric footprint, peaks, then dissolves into tiny pixels.
> Strong readable silhouette, no letters, no rune text, crisp 16-bit pixels,
> consistent center point in every frame.

### `muhtar_minigame/assets/sprites/fx/dust_steps.png`

**Для чего:** короткие пыльные следы под ногами игрока и врагов при движении по
земле и дороге.

**Промпт:**

> Pixel-art dust step VFX sheet, 6 frames in one row, each cell 64x64,
> transparent background. Small warm beige dust puffs rising from two feet,
> first frame tiny, middle frames expand, last frame fades into two pixels, no
> smoke cloud, crisp 16-bit pixels, centered at the ground baseline.

### `muhtar_minigame/assets/sprites/fx/hit_slash.png`

**Для чего:** эффект попадания мечом в бою.

**Промпт:**

> Pixel-art combat hit VFX sheet, 6 frames in one row, each cell 128x128,
> transparent background. Amber-white diagonal slash, two tiny red impact pixels,
> bright center flash, expands and fades quickly, sharp blocky pixels, no text,
> no gore, no weapon outside the effect, consistent center.

### `muhtar_minigame/assets/sprites/fx/shield_block.png`

**Для чего:** эффект щита при блокировании урона.

**Промпт:**

> Pixel-art shield block VFX sheet, 6 frames in one row, each cell 128x128,
> transparent background. Blue-gray circular shield flash with three amber
> square sparks, appears as a protective arc, contracts and fades, crisp 16-bit
> pixels, no text, no logo, no character, centered effect.

### `muhtar_minigame/assets/sprites/fx/heal_sparkle.png`

**Для чего:** эффект лечения и использования зелья/медицинской способности.

**Промпт:**

> Pixel-art healing VFX sheet, 8 frames in one row, each cell 128x128,
> transparent background. Mint-green plus-like spark shapes and three warm white
> particles rise upward, bright but not neon, form a gentle arc, then vanish,
> no written medical symbol, no text, crisp 16-bit pixels.

### `muhtar_minigame/assets/sprites/fx/burn_flame.png`

**Для чего:** эффект горения от Шаурмека и огненной кости.

**Промпт:**

> Pixel-art burn VFX sheet, 8 frames in one row, each cell 96x96, transparent
> background. Small orange-red flame with a yellow core, two dark ember pixels,
> flickers without changing position, no smoke text, no character, crisp 16-bit
> pixels, clean transparent edges.

### `muhtar_minigame/assets/sprites/fx/coin_burst.png`

**Для чего:** вспышка монет при награде, покупке и победе над врагом.

**Промпт:**

> Pixel-art reward coin burst sheet, 8 frames in one row, each cell 96x96,
> transparent background. Three gold coins pop upward with tiny amber sparkles,
> rotate by simple pixel highlights, peak and fall, no currency symbol, no text,
> crisp 16-bit pixels, strong contrast.

### `muhtar_minigame/assets/sprites/fx/quest_complete.png`

**Для чего:** эффект завершения квеста рядом с уведомлением.

**Промпт:**

> Pixel-art quest complete VFX sheet, 8 frames in one row, each cell 128x128,
> transparent background. Amber starburst, teal check-shaped abstract spark and
> small violet particles, no actual letter or readable check text, expands from
> center and fades, crisp 16-bit pixel art.

### `muhtar_minigame/assets/sprites/fx/water_ripple.png`

**Для чего:** мягкая анимация ряби около берегов Моста и рыбацкой точки.

**Промпт:**

> Pixel-art water ripple VFX sheet, 6 frames in one row, each cell 96x64,
> transparent background. Two cyan pixel arcs expand across dark teal water,
> brighten in the middle and fade at the end, no foam, no text, clean one-pixel
> highlights, crisp 16-bit pixels.

### `muhtar_minigame/assets/sprites/fx/level_up.png`

**Для чего:** редкий эффект повышения уровня героя и открытия награды.

**Промпт:**

> Pixel-art level-up VFX sprite sheet, 8 frames in one row, each cell 128x128,
> transparent background. Golden vertical light column, small teal and violet
> particles spiral upward, final frame leaves a warm halo, no number, no text,
> no character, crisp 16-bit pixel art, centered on the ground point.

---

# 6. Фоны и большие иллюстрации

Эти картинки не должны использоваться вместо игровых тайлов. Они нужны для
splash, меню, загрузочного экрана, титульных карточек и будущих сюжетных
переходов.

### `muhtar_minigame/assets/sprites/backgrounds/splash_background.png`

**Для чего:** атмосферный фон стартового splash screen за логотипом игры.

**Промпт:**

> Wide 1280x720 pixel-art illustration for a humorous 2D isometric RPG splash
> screen: a small railway station in the foreground, a long green park leading
> toward a gray bridge, distant purple city buildings, warm amber sunrise,
> teal shadows, one tiny courier silhouette on the path, large calm dark area in
> the upper-left and center for runtime logo text, hand-crafted 16-bit pixel art,
> no letters, no logos, no watermark, no UI controls.

### `muhtar_minigame/assets/sprites/backgrounds/title_background.png`

**Для чего:** фон главного меню или экрана продолжения игры.

**Промпт:**

> Wide 1280x720 pixel-art game title background, humorous urban isometric world
> collage: station rails on the left, green park in the middle, bridge and
> water on the right, tiny silhouettes of the courier, Ariana, Ribka and one
> gopnik, strong amber and cyan rim light, intentionally quiet central area for
> menu buttons, no text, no logos, no watermark, crisp 16-bit art.

### `muhtar_minigame/assets/sprites/backgrounds/battle_backgrounds.png`

**Для чего:** набор задников для боёв: Парк, Вокзал, Мост и интерьер магазина.

**Промпт:**

> Pixel-art battle background atlas with 4 separate 640x360 scenes: green park
> path with trees, railway platform with rails, gray bridge over blue-green
> water, and cozy convenience-store aisle. Keep the lower center dark and calm
> for the 3x3 dice board, leave both side edges readable for portraits, no
> characters, no text, no logos, hand-crafted 16-bit pixel art, consistent
> perspective and palette.

### `muhtar_minigame/assets/sprites/backgrounds/location_cards.png`

**Для чего:** маленькие карточки-предпросмотры локаций в будущем журнале карты.

**Промпт:**

> Pixel-art location thumbnail atlas with 10 separate 256x160 cards, one for
> each world location: station, park, bridge, horse hub, diner, college,
> dormitory, parcel pickup point, convenience store and cheburek diner. Each
> card has a distinct silhouette and color, no text or labels, consistent
> isometric perspective, crisp 16-bit pixels, no watermark.

---

# 7. Чек-лист перед добавлением ассета

## Для портретов

- файл имеет точное имя NPC или врага;
- размер 512×576;
- лицо не обрезано сверху;
- в картинке нет текста и настоящих логотипов;
- лицо остаётся различимым в рамке 64×78 px;
- фон не конфликтует с янтарной рамкой диалога.

## Для world-спрайтов

- PNG с alpha channel;
- атлас строго 4×4;
- все клетки одного размера;
- ступни на общей baseline;
- нет тени, которая вылезает в соседнюю клетку;
- направление «вниз» находится в первой строке;
- файл не содержит сетки и направляющих.

## Для тайлов

- ромб 80×40, прозрачные углы;
- соседние тайлы не имеют случайных швов;
- тайл портала остаётся читаемым без текста;
- вариации одного типа не меняют геометрию;
- атлас экспортирован без масштабирования и интерполяции.

## Для UI и эффектов

- прозрачный фон вне объекта;
- края не обрезаны;
- текст генерируется Flutter, а не нейросетью;
- контраст достаточен на фоне `#171923`;
- для анимации одинаковая точка привязки во всех кадрах.

# 8. Рекомендуемый манифест файлов

Полный комплект из этого документа — **78 файлов/атласов**:

- 14 портретов: игрок, наградный скин, 7 NPC и 5 врагов;
- 14 world-атласов персонажей: 2 игрока, 7 NPC и 5 врагов;
- 25 наборов тайлов, пропов и зданий;
- 11 атласов UI, костей и предметов;
- 10 атласов эффектов;
- 4 больших фоновых атласа/иллюстрации.

Не нужно генерировать всё одним запросом. Генерируйте по одному типу ассета
серией, сохраняя один style reference и один seed для персонажа. Нельзя
смешивать в одной серии портреты, тайлы и UI: у них разные требования к
прозрачности и масштабу.

# 9. Что подключается первым

В текущем коде уже используются следующие имена:

- `assets/portraits/player.png`;
- `assets/portraits/gopnik.png`;
- `assets/portraits/shaurmek.png`;
- `assets/portraits/viktor_korneplod.png`.

Следующим безопасным шагом можно добавить без изменения логики:

1. `ariana.png`, `sofia.png`, `ribka.png`, `baba_galya.png`, `alenka.png`,
   `malek.png`, `buber.png`;
2. `player_ribka_reward.png`;
3. `slime.png` и `goblin.png` для будущих врагов.

World-спрайты, тайлы и эффекты требуют отдельного подключения в Flame:
`SpriteComponent`, `SpriteAnimationComponent`, atlas slicing и замена
процедурного рендера. До подключения новые PNG не должны автоматически
заменять процедурные заглушки.
