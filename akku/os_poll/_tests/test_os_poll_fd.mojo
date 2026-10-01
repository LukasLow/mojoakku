# Concern: PollFd record construction, empty revents, is_ready, clear() and the
# negative-fd "skip" representation.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.os_poll import PollEvents, PollFd


def test_construction_starts_empty() raises:
    var record = PollFd(7, PollEvents.READ)
    assert_equal(record.fd, 7)
    assert_true(record.events == PollEvents.READ)
    assert_true(record.revents.is_empty())
    assert_false(record.is_ready())


def test_clear_resets_revents() raises:
    var record = PollFd(7, PollEvents.READ)
    record.revents = PollEvents.READ | PollEvents.HANGUP
    assert_true(record.is_ready())
    record.clear()
    assert_true(record.revents.is_empty())
    assert_false(record.is_ready())


def test_negative_fd_is_representable() raises:
    var skipped = PollFd(-1, PollEvents.READ)
    assert_true(skipped.fd < 0)


def test_printing_reports_fields() raises:
    var text = String(PollFd(3, PollEvents.WRITE))
    assert_true("3" in text)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
