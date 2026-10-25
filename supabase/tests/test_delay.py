import unittest

from harness import db, member, sample, uuid


class DelayPolicyTests(unittest.TestCase):
    def pending(self):
        return (member(1, delay=2) + member(2, delay=1) + sample(1, 1, observed="'2026-10-25T10:00:00Z'")
                + sample(2, 1, distance=5, observed="'2026-10-25T10:00:00Z'"))

    def release(self, sql):
        return db().run(sql + "select release_at from encounter;")[-1][0]

    def test_reduction_keeps_the_floor(self):
        self.assertEqual(self.release(self.pending() + "update preferences set delay_hours = 0 where account_id = '%s';" % uuid(1)), "2026-10-25 12:00:00+00")

    def test_increase_extends(self):
        self.assertEqual(self.release(self.pending() + "update preferences set delay_hours = 6 where account_id = '%s';" % uuid(2)), "2026-10-25 16:00:00+00")

    def test_released_rows_untouched(self):
        sql = self.pending() + "update encounter set state = 'released'; update preferences set delay_hours = 24 where account_id = '%s';" % uuid(1)
        self.assertEqual(self.release(sql), "2026-10-25 12:00:00+00")


if __name__ == "__main__":
    unittest.main()
