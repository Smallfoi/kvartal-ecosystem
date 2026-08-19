import 'package:flutter/material.dart';

/// Палитра КВАРТАЛА — язык сайта МАТА (D-42).
///
/// Значения взяты 1:1 из `САЙТ МАТА/styles.css`, чтобы приложение читалось как
/// продолжение сайта, а не как его пересказ. Приложение было тёмным; теперь база
/// светлая — молочный фон, бумажные карточки, графит для контрастных блоков.
class AppColors {
  AppColors._();

  // ── Поверхности ───────────────────────────────────────────────────────────
  /// Общий фон экрана (молочный).
  static const bg = Color(0xFFF4F1EA);

  /// Тёплая «бумага» — карточки и панели поверх фона.
  static const paper = Color(0xFFFFFDF8);

  /// Чистая белая панель — там, где нужен максимальный контраст с фоном.
  static const panel = Color(0xFFFFFFFF);

  /// Холодная подложка: чипы, аватары, неактивные состояния.
  static const soft = Color(0xFFE7EEF0);

  /// Тёмный графит: контраст-блоки, главные кнопки, «своя» строка в рейтинге.
  static const graphite = Color(0xFF20252B);

  /// Полупрозрачная бумага для плавающих панелей над картой.
  static const glassPaper = Color(0xF2FFFDF8);

  // ── Текст ─────────────────────────────────────────────────────────────────
  static const ink = Color(0xFF111317);
  static const muted = Color(0xFF6F7278);
  static const faint = Color(0xFF8A8D93);
  static const disabled = Color(0xFFA9ACB1);
  static const onDark = Color(0xFFFFFFFF);

  /// Тонкие границы — rgba(17, 19, 23, .12) с сайта.
  static const line = Color(0x1F111317);

  // ── Акценты ───────────────────────────────────────────────────────────────
  /// Технический голубой — главный сигнал (фокус, запись, ссылки).
  static const accent = Color(0xFF57BCD8);

  /// Затемнённый голубой: тем же цветом можно писать текст по светлому.
  static const accentInk = Color(0xFF167A95);

  /// Лайм — спортивный сигнал, дозированно (главное действие, свои зоны).
  static const lime = Color(0xFFDFF45F);

  // ── Ночная поверхность ────────────────────────────────────────────────────
  // Сайт светлый принципиально, но Квартал держат в руке на улице и часто в
  // темноте: молочный экран во весь размер слепит. Вёрстка и типографика те же,
  // меняются только поверхности.
  static const nightBg = Color(0xFF14181C);
  static const nightPaper = Color(0xFF1B2026);
  static const nightInk = Color(0xFFF2EFE8);
  static const nightMuted = Color(0xFF9AA0A6);
  static const nightLine = Color(0x24FFFDF8);

  // ── Статусы ───────────────────────────────────────────────────────────────
  // Цвет здесь несёт смысл, а не оформление: только состояния, никогда — декор.
  static const success = Color(0xFF2E9E5B);
  static const warning = Color(0xFFE0A325);
  static const error = Color(0xFFD5453B);
  static const info = accent;

  // ── Зоны на карте ─────────────────────────────────────────────────────────
  /// Свои зоны — единственное яркое пятно на карте.
  static const zoneMine = lime;

  /// Спорные — голубой акцент.
  static const zoneContested = accent;

  /// Чужие — графит; на карте даётся с прозрачностью.
  static const zoneEnemy = graphite;

  static const zoneNeutral = Color(0xFFCBD3D6);
  static const zoneFading = Color(0xFFB9C1C4);

  // ── Переходные псевдонимы ─────────────────────────────────────────────────
  // Имена из тёмной темы. На них завязано ~720 мест в экранах; удалять их будем
  // по мере перевода экранов на новые имена, иначе пришлось бы менять всё разом.
  static const electricBlue = accent;
  static const accentBlue = accent;
  static const iceWhite = soft;
  static const bgDark = bg;
  static const bgSurface = paper;
  static const bgCard = paper;
  static const bgElevated = panel;
  static const separator = line;
  static const glass = glassPaper;
  static const textPrimary = ink;
  static const textSecondary = muted;
  static const textTertiary = faint;
  static const textDisabled = disabled;
  static const hexNeutral = zoneNeutral;
  static const hexOwned = zoneMine;
  static const hexEnemy = zoneEnemy;
  static const hexContested = zoneContested;
  static const hexFading = zoneFading;
  static const gradientStart = accent;
  static const gradientEnd = accentInk;
}
