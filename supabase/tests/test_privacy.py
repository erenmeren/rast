import unittest

from harness import SqlError, as_user, db, member, sample, uuid


def like(n, target, op):
    return as_user(uuid(n), "select public.like_account('%s','%s');" % (uuid(target), uuid(op)))


class PrivacyTests(unittest.TestCase):
    def pending(self):
        return member(1, delay=2) + member(2, delay=2) + sample(1, 1) + sample(2, 1, distance=5)

    def released(self):
        return (member(1, delay=0) + member(2, delay=0) + sample(1, 1, observed="now() - interval '1 second'")
                + sample(2, 1, distance=5, observed="now() - interval '1 second'") + "select app.release_due_encounters();")

    def test_pending_encounter_and_pair_are_invisible(self):
        rows = db().run(self.pending() + as_user(uuid(1), "select count(*) from encounter; select count(*) from pair; select count(*) from pair_event;"))
        self.assertEqual(rows[-3:], [["0"], ["0"], ["0"]])

    def test_released_encounter_is_visible_without_times(self):
        rows = db().run(self.released() + as_user(uuid(1), "select state from encounter; select count(*) from pair;"))
        self.assertEqual(rows[-2:], [["released"], ["1"]])
        for col, table in [("created_at", "encounter"), ("created_at", "pair")]:
            with self.subTest(col=col, table=table), self.assertRaisesRegex(SqlError, "permission denied"):
                db().run(self.released() + as_user(uuid(1), "select %s from %s;" % (col, table)))

    def test_target_cannot_see_who_liked_them(self):
        sql = self.released() + like(1, 2, 700)
        rows = db().run(sql + as_user(uuid(2), "select count(*) from pair_like; select count(*) from pair_event;"))
        self.assertEqual(rows[-2:], [["0"], ["0"]])
        self.assertEqual(db().run(sql + as_user(uuid(1), "select count(*) from pair_like;"))[-1], ["1"])


if __name__ == "__main__":
    unittest.main()
