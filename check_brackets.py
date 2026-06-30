import pathlib, sys
text = pathlib.Path('lib/features/admin/admin_home_screen.dart').read_text(encoding='utf-8')
openers = {'(': ')', '[': ']', '{': '}'}
closers = {')': '(', ']': '[', '}': '{'}
stack = []
line = 1
for ch in text:
    if ch == '\n':
        line += 1
    if ch in openers:
        stack.append((ch, line))
    elif ch in closers:
        if stack and stack[-1][0] == closers[ch]:
            stack.pop()
        else:
            print('Mismatch', ch, 'at line', line)
            sys.exit(0)
if stack:
    print('Unclosed', stack[-1])
else:
    print('Balanced')
