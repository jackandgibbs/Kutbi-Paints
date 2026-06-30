from pathlib import Path
text = Path('lib/features/admin/admin_home_screen.dart').read_text(encoding='utf-8')
openers = {'(': ')', '[': ']', '{': '}'}
closers = {')': '(', ']': '[', '}': '{'}
stack = []
lines = text.splitlines()
for i in range(258, 820):
    line = lines[i]
    for ch in line:
        if ch in openers:
            stack.append((ch, i + 1))
        elif ch in closers:
            if stack and stack[-1][0] == closers[ch]:
                stack.pop()
            else:
                print('MISMATCH', ch, 'at', i + 1, 'depth', len(stack), 'line', line)
                raise SystemExit
    if len(stack) < 10 and any(c in line for c in '()[]{}'):
        print(i + 1, len(stack), line.strip())
print('final depth', len(stack))
