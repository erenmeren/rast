import unittest

from harness import as_user, db, member, sample, uuid


T0 = "date_trunc('hour', now()) - interval '2 hours'"  # inside the 24 h sample window on any day


class DelayPolicyTests(unittest.TestCase):
    def pending(self):
        return (member(1, delay=2) + member(2, delay=1) + sample(1, 1, observed=T0)
                + sample(2, 1, distance=5, observed=T0))

    def release(self, sql):
        """Hours after T0 at which the single encounter releases."""
        return db().run(sql + "select (extract(epoch from release_at - (%s)) / 3600)::int from encounter;" % T0)[-1][0]

    def test_reduction_keeps_the_floor(self):
        self.assertEqual(self.release(self.pending() + "update preferences set delay_hours = 0 where account_id = '%s';" % uuid(1)), "2")

    def test_increase_extends(self):
        self.assertEqual(self.release(self.pending() + "update preferences set delay_hours = 6 where account_id = '%s';" % uuid(2)), "6")

    def test_client_can_change_delay_and_the_floor_extends(self):
        sql = self.pending() + as_user(uuid(2), "update preferences set delay_hours = 6 where account_id = '%s';" % uuid(2))
        self.assertEqual(self.release(sql), "6")

    def test_released_rows_untouched(self):
        sql = self.pending() + "update encounter set state = 'released'; update preferences set delay_hours = 24 where account_id = '%s';" % uuid(1)
        self.assertEqual(self.release(sql), "2")


if __name__ == "__main__":
    unittest.main()
