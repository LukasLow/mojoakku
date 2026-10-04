# core.mojo — private shared formatting logic for akku/text_format.
#
# These helpers exist once so the per-value formatters (format_int,
# format_float, format_string, format_bool) do not duplicate the same
# codepoint-counting, padding, grouping, ASCII and float-digit logic. Nothing
# here is public API: the public surface is the top-level *.mojo entries.

from std.format import repr
from std.math import floor, log10, round

from .format_arg import FormatArg


# codepoint_count — the number of codepoints in borrowed text.
def codepoint_count(text: StringSpan) -> Int:
    return text.count_codepoints()


# byte_offset_for_codepoints — the byte offset of the first `n` codepoints, or
# the byte length when the text is shorter. Never splits a codepoint.
def byte_offset_for_codepoints(text: StringSpan, n: Int) -> Int:
    if n <= 0:
        return 0
    var count = 0
    var offset = 0
    var bytes = text.as_bytes()
    var nbytes = len(bytes)
    while offset < nbytes and count < n:
        var b = bytes[offset]
        if b < 0x80:
            offset += 1
        elif b >= 0xC2 and b <= 0xDF:
            offset += 2
        elif b >= 0xE0 and b <= 0xEF:
            offset += 3
        elif b >= 0xF0 and b <= 0xF4:
            offset += 4
        else:
            offset += 1
        count += 1
    if offset > nbytes:
        offset = nbytes
    return offset


# pad — pad `content` to `width` codepoints with `fill`, per alignment.
def pad(
    var content: String,
    width: Int,
    align: Int,
    fill: Codepoint,
    content_codepoints: Int,
) -> String:
    if width <= 0 or content_codepoints >= width:
        return content^
    var needed = width - content_codepoints
    if align == 1:      # LEFT
        return content + String(fill) * needed
    if align == 3:      # CENTER: extra fill on the right
        var left = needed // 2
        var right = needed - left
        return String(fill) * left + content + String(fill) * right
    if align == 4:      # SIGN_AWARE (only used for numbers)
        return sign_aware_pad(content, needed, fill)
    # RIGHT and DEFAULT (numbers handled by the caller; strings/bools default LEFT)
    return String(fill) * needed + content


# sign_aware_pad — insert `needed` fill codepoints after a leading sign
# ('+', '-', or ' ') and before the digits.
def sign_aware_pad(content: String, needed: Int, fill: Codepoint) -> String:
    var padstr = String(fill) * needed
    var bytes = content.as_bytes()
    if len(bytes) > 0:
        var first = Int(bytes[0])
        if first == 43 or first == 45 or first == 32:   # '+', '-', ' '
            return String(content[byte=0:1]) + padstr + String(content[byte=1:])
    return padstr + content


# group_digits — insert a separator every three digits of the integer part.
def group_digits(digits: String, separator: String) -> String:
    var sign = ""
    var body = String(digits)
    var dbytes = digits.as_bytes()
    if len(dbytes) > 0:
        var first = Int(dbytes[0])
        if first == 45 or first == 43:   # '-', '+'
            sign = String(digits[byte=0:1])
            body = String(digits[byte=1:])
    var out = String()
    var n = body.byte_length()
    for i in range(n):
        if i > 0 and (n - i) % 3 == 0:
            out += separator
        out += String(body[byte=i:i + 1])
    return sign + out


# pad_numeric — pad sign+body to `width` codepoints for a number.
# `align_id` is the raw Alignment id (0 DEFAULT, 1 LEFT, 2 RIGHT, 3 CENTER,
# 4 SIGN_AWARE). Zero padding is sign/prefix-aware and applies in the default
# and SIGN_AWARE alignments.
def pad_numeric(
    sign: String,
    body: String,
    width: Int,
    fill: Codepoint,
    align_id: Int,
    zero_pad: Bool,
) -> String:
    var full = sign + body
    var have = full.count_codepoints()
    if width <= 0 or have >= width:
        return full^
    var needed = width - have
    var zero_mode = zero_pad and (align_id == 0 or align_id == 4)
    if zero_mode:
        return sign + String(Codepoint(48)) * needed + body
    if align_id == 1:      # LEFT
        return full + String(fill) * needed
    if align_id == 3:      # CENTER
        var left = needed // 2
        var right = needed - left
        return String(fill) * left + full + String(fill) * right
    if align_id == 4:      # SIGN_AWARE without zero pad
        return sign + String(fill) * needed + body
    return String(fill) * needed + full


# ascii_digit — an Int in [0, 36) as its lowercase ASCII digit character.
def ascii_digit(v: Int) -> String:
    if v < 10:
        return String(chr(48 + v))
    return String(chr(87 + v))


# ascii_digit_upper — an Int in [0, 36) as its uppercase ASCII digit character.
def ascii_digit_upper(v: Int) -> String:
    if v < 10:
        return String(chr(48 + v))
    return String(chr(55 + v))


# int_to_radix — a UInt magnitude in the given radix as ASCII digits.
def int_to_radix(magnitude: UInt, radix: Int, upper: Bool) -> String:
    if magnitude == 0:
        return "0"
    var digits = String()
    var m = magnitude
    var base = UInt(radix)
    while m > 0:
        var d = Int(m % base)
        if upper:
            digits = ascii_digit_upper(d) + digits
        else:
            digits = ascii_digit(d) + digits
        m = m // base
    return digits


# format_fixed — `value` with exactly `precision` digits after the decimal
# point, rounded half-to-even. A precision of 0 keeps no point unless
# `force_point`. The result never carries a sign (the caller adds it).
def format_fixed(value: Float64, precision: Int, force_point: Bool) -> String:
    var scale = 1.0
    for _ in range(precision):
        scale *= 10.0
    var scaled = value * scale
    # Add the sign of zero so -0.4 rounds away from zero (round(-0.4) == 0.0 in
    # Mojo, but the magnitude is positive here so the result is correct either
    # way); handle negatives by rounding the magnitude and restoring the sign.
    var negative = scaled < 0.0
    var mag = scaled
    if negative:
        mag = -scaled
    var half = floor(mag) + 0.5
    var rounded: Int
    if mag == half:
        # Exact tie: round to even.
        var lower = Int(floor(mag))
        if lower % 2 == 0:
            rounded = lower
        else:
            rounded = lower + 1
    else:
        rounded = Int(round(mag))
    var digits = String(rounded)
    var out = String()
    if precision == 0:
        out = digits
        if force_point:
            out += "."
        if negative:
            out = "-" + out
        return out
    while digits.byte_length() <= precision:
        digits = "0" + digits
    var point = digits.byte_length() - precision
    out = String(digits[byte=0:point]) + "." + String(digits[byte=point:])
    if negative:
        out = "-" + out
    return out


# format_scientific — `value` in scientific notation with `precision` digits
# after the point, rounded half-to-even. The exponent uses at least two digits.
def format_scientific(
    value: Float64, precision: Int, upper: Bool
) -> String:
    var e_char = "e"
    if upper:
        e_char = "E"
    if value == 0.0:
        var zero = format_fixed(0.0, precision, False)
        return zero + e_char + "+00"
    var negative = value < 0.0
    var mag = value
    if negative:
        mag = -value
    var exponent = Int(floor(log10(mag)))
    # Keep the mantissa in [1, 10): correct for log10 rounding at powers of ten.
    var mantissa = mag / pow10(exponent)
    if mantissa < 1.0:
        mantissa *= 10.0
        exponent -= 1
    elif mantissa >= 10.0:
        mantissa /= 10.0
        exponent += 1
    var mant = format_fixed(mantissa, precision, False)
    var sign = "+"
    var abs_exp = exponent
    if exponent < 0:
        sign = "-"
        abs_exp = -exponent
    var exp_digits = String(abs_exp)
    if exp_digits.byte_length() < 2:
        exp_digits = "0" + exp_digits
    var out = mant + e_char + sign + exp_digits
    if negative:
        out = "-" + out
    return out


# pow10 — 10.0 ** exp for a small integer exponent.
def pow10(exp: Int) -> Float64:
    var out = 1.0
    if exp >= 0:
        for _ in range(exp):
            out *= 10.0
    else:
        for _ in range(-exp):
            out /= 10.0
    return out


# is_special_float — whether `value` is inf/nan (so fixed/scientific fall back).
def is_special_float(value: Float64) -> Bool:
    # A finite Float64 equals itself and is within a huge bound; use the std
    # predicates by bit trick: inf and nan both fail `value - value == 0.0`.
    return not (value - value == 0.0)


# special_float_text — "inf" or "nan" (lowercase; 'F' is an alias of 'f').
def special_float_text(value: Float64) -> String:
    if value != value:      # nan
        return "nan"
    if value < 0.0:
        return "-inf"
    return "inf"


# write_repr_of_arg — append the repr form of a stored argument.
def write_repr_of_arg(mut writer: Some[Writer], arg: FormatArg):
    if arg.kind() == 0:
        writer.write(repr(arg.as_int()))
    elif arg.kind() == 1:
        writer.write(repr(arg.as_float()))
    elif arg.kind() == 2:
        writer.write(repr(arg.text()))
    else:
        writer.write(repr(arg.as_bool()))
