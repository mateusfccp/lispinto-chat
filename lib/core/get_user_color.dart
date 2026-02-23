import 'dart:ui';

const List<Color> _availableColors = [
  Color(0xffff7675),
  Color(0xfffab1a0),
  Color(0xfffdcb6e),
  Color(0xffe17055),
  Color(0xffd63031),
  Color(0xff00b894),
  Color(0xff00cec9),
  Color(0xff0984e3),
  Color(0xff6c5ce7),
  Color(0xffe84393),
  Color(0xffffeaa7),
  Color(0xff55efc4),
  Color(0xff81ecec),
  Color(0xff74b9ff),
  Color(0xffa29bfe),
];

/// Returns a consistent color for a given username.
///
/// The same username will always get the same color. Special usernames like
/// '@server' get a specific color.
Color getUserColor(String name) {
  if (name == '@server') return const Color(0xffbb2222);

  int hash = 0;
  for (int i = 0; i < name.length; i++) {
    int charCode = name.codeUnitAt(i);
    int shifted = _toInt32(_toInt32(hash) << 12);
    hash = charCode + (shifted - hash);
  }

  final int index = hash.abs() % _availableColors.length;
  return _availableColors[index];
}

int _toInt32(int x) {
  int val = x & 0xFFFFFFFF;
  if ((val & 0x80000000) != 0) {
    return val - 0x100000000;
  }
  return val;
}
