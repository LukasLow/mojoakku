# Concern: PollEvents bit values, |/&/contains, named predicates and printing;
# plus the PollErrorKind/PollError printing and equality surface.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.os_poll import PollEvents, PollError, PollErrorKind


def test_event_bit_values() raises:
    assert_equal(PollEvents.READ.bits(), UInt16(0x0001))
    assert_equal(PollEvents.PRIORITY.bits(), UInt16(0x0002))
    assert_equal(PollEvents.WRITE.bits(), UInt16(0x0004))
    assert_equal(PollEvents.ERROR.bits(), UInt16(0x0008))
    assert_equal(PollEvents.HANGUP.bits(), UInt16(0x0010))
    assert_equal(PollEvents.INVALID.bits(), UInt16(0x0020))
    assert_equal(PollEvents.NONE.bits(), UInt16(0x0000))


def test_none_is_empty_and_falsy() raises:
    assert_true(PollEvents.NONE.is_empty())
    assert_false(PollEvents.NONE.__bool__())
    assert_false(PollEvents.READ.is_empty())
    assert_true(PollEvents.READ.__bool__())


def test_or_and_contains() raises:
    var want = PollEvents.READ | PollEvents.WRITE
    assert_equal(want.bits(), UInt16(0x0005))
    assert_true(want.contains(PollEvents.READ))
    assert_true(want.contains(PollEvents.WRITE))
    assert_false(want.contains(PollEvents.ERROR))
    assert_true((want & PollEvents.READ) == PollEvents.READ)
    assert_true((want & PollEvents.ERROR).is_empty())


def test_named_predicates() raises:
    var result = PollEvents.READ | PollEvents.HANGUP
    assert_true(result.is_readable())
    assert_false(result.is_writable())
    assert_true(result.has_hangup())
    assert_false(result.has_error())
    assert_false(result.is_invalid())
    var broken = PollEvents.INVALID | PollEvents.ERROR
    assert_true(broken.is_invalid())
    assert_true(broken.has_error())


def test_events_and_errors_print_symbolically() raises:
    assert_true("READ" in String(PollEvents.READ | PollEvents.WRITE))
    assert_true("NONE" in String(PollEvents.NONE))
    var err = PollError(PollErrorKind.INVALID_FD, "wait", "negative fd")
    var text = String(err)
    assert_true("INVALID_FD" in text)
    assert_true("wait" in text)
    assert_true(err.kind == PollErrorKind.INVALID_FD)
    assert_false(PollErrorKind.INVALID_TIMEOUT == PollErrorKind.SYSCALL)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
