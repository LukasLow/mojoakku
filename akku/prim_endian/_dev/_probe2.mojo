from std.collections import List


def take_span(x: Span[UInt8, _]) -> Int:
    return len(x)


def main():
    var dst: List[UInt8] = [0, 0]
    print("literal list as span:", take_span(dst), len(dst))
