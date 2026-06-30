import 'package:flutter/material.dart';

class QRStickerPalette {
  final String key;
  final String name;
  final Color primary;
  final Color secondary;
  final Color text;
  final Color accent;

  const QRStickerPalette({
    required this.key,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.text,
    required this.accent,
  });
}

const qrStickerPalettes = <QRStickerPalette>[
  QRStickerPalette(
    key: 'teal',
    name: 'Teal',
    primary: Color(0xFF1D9E75),
    secondary: Color(0xFFE1F5EE),
    text: Color(0xFF085041),
    accent: Color(0xFF0F6E56),
  ),
  QRStickerPalette(
    key: 'purple',
    name: 'Purple',
    primary: Color(0xFF7F77DD),
    secondary: Color(0xFFEEEDFE),
    text: Color(0xFF3C3489),
    accent: Color(0xFF534AB7),
  ),
  QRStickerPalette(
    key: 'coral',
    name: 'Coral',
    primary: Color(0xFFD85A30),
    secondary: Color(0xFFFAECE7),
    text: Color(0xFF712B13),
    accent: Color(0xFF993C1D),
  ),
  QRStickerPalette(
    key: 'blue',
    name: 'Blue',
    primary: Color(0xFF378ADD),
    secondary: Color(0xFFE6F1FB),
    text: Color(0xFF0C447C),
    accent: Color(0xFF185FA5),
  ),
  QRStickerPalette(
    key: 'green',
    name: 'Green',
    primary: Color(0xFF639922),
    secondary: Color(0xFFEAF3DE),
    text: Color(0xFF27500A),
    accent: Color(0xFF3B6D11),
  ),
  QRStickerPalette(
    key: 'amber',
    name: 'Amber',
    primary: Color(0xFFBA7517),
    secondary: Color(0xFFFAEEDA),
    text: Color(0xFF633806),
    accent: Color(0xFF854F0B),
  ),
  QRStickerPalette(
    key: 'red',
    name: 'Red',
    primary: Color(0xFFE24B4A),
    secondary: Color(0xFFFCEBEB),
    text: Color(0xFF501313),
    accent: Color(0xFFA32D2D),
  ),
  QRStickerPalette(
    key: 'rose',
    name: 'Rose',
    primary: Color(0xFFD4537E),
    secondary: Color(0xFFFBEAF0),
    text: Color(0xFF72243E),
    accent: Color(0xFF993556),
  ),
  QRStickerPalette(
    key: 'navy',
    name: 'Navy',
    primary: Color(0xFF0F4C75),
    secondary: Color(0xFFE8EEF7),
    text: Color(0xFF051B2F),
    accent: Color(0xFF1B5E9D),
  ),
];

final qrStickerPaletteMap = {
  for (final palette in qrStickerPalettes) palette.key: palette,
};
