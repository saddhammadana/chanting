import 'package:flutter/material.dart';

/// Dhamma-inspired cream, brown, and gold palette.
abstract class AppColors {
  // ---- Light ----
  static const cream = Color(0xFFFFF9EE); // Main background.
  static const creamLight = Color(0xFFFFFCF5); // Card background.
  static const brown = Color(0xFF5F3C1B); // Primary action / AppBar color.
  static const brownDark = Color(0xFF442B16);
  static const brownSoft = Color(0xFF866746); // Secondary text.
  static const gold = Color(0xFFE49A12); // Warm devotional accent.
  static const goldDark = Color(0xFFB96F00);
  static const goldSoft = Color(0xFFFFE8B9); // Soft gold fill.
  static const creamBorder = Color(0xFFF1C26B); // Fine illuminated border.
  static const creamField = Color(
    0xFFFFF3D9,
  ); // Input fill, below card surface.

  // ---- Dark ----
  static const darkBackground = Color(0xFF241C14); // Near-black brown.
  static const darkSurface = Color(0xFF322718); // Dark card background.
  static const darkCream = Color(0xFFE8DCC3); // Primary dark text.
  static const darkCreamSoft = Color(0xFFB8A88C); // Secondary dark text.
  static const darkGold = Color(0xFFD9B84A); // Dark accent.
  static const darkGoldSoft = Color(0xFF473A22); // Soft gold dark fill.
  static const darkBorder = Color(0xFF443725); // Dark card border.
  static const darkField = Color(0xFF1E1710); // Dark input fill.

  // ---- Sampled from artwork ----
  // One-off values measured off the design files. They live here so every
  // colour in the app is named in one place; each is used by the widget its
  // name points at.
  static const beige = Color(0xFFF4EADB); // Quiet fill behind tags and chips.
  static const panelEdge = Color(0xFFE5DCCF); // Flat panel border.
  static const rowEdge = Color(0xFFEFE6D9); // Selected prayer-row border.
  static const creamWarm = Color(0xFFFBEBCB); // Warm end of a cream gradient.
  static const watermarkGold = Color(0xFFC9A227); // Lotus mark on a page tile.
  static const scanFrameGold = Color(0xFFF2B23A); // QR scan frame brackets.
  static const goalInk = Color(0xFF7E520C); // Goal figure beside the ring.
  static const playDiscTop = Color(0xFFE7A22C); // Gold play button gradient.
  static const playDiscBottom = Color(0xFFD8911E);

  // Bottom navigation bar and its start button.
  static const navBar = Color(0xFFFEF4E3);
  static const navBorder = Color(0xFFF7DDB4);
  static const navRest = Color(0xFF3B2416);
  static const navActiveIcon = Color(0xFFD98E2F);
  static const navActiveLabel = Color(0xFFC06A1F);
  static const navStartShadow = Color(0x33D98E2F);
  static const navStartRimTop = Color(0xFFEE9B2C);
  static const navStartRimBottom = Color(0xFFB86C20);
  static const navStartHaloTop = Color(0xFFFFE9A6);
  static const navStartHaloBottom = Color(0xFFF0B04A);
  static const navStartDiscTop = Color(0xFFFBB54E);
  static const navStartDiscBottom = Color(0xFFC67921);

  // Toast kinds. Warning is [gold].
  static const toastSuccess = Color(0xFF4E9A3F);
  static const toastInfo = Color(0xFF2F7BDD);
  static const toastError = Color(0xFFD63A32);
}
