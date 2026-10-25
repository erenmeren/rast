import unittest

from harness import SqlError, as_user, db, member, uuid


class HelperTests(unittest.TestCase):
    def test_age_on(self):
        rows = db().run("select app.age_on('1998-05-14', '2026-10-25'), app.age_on('1998-10-26', '2026-10-25'), app.age_on('2008-02-29', '2026-02-28'), app.age_on('2008-02-29', '2026-03-01');")
        self.assertEqual(rows, [["28", "27", "17", "18"]])

    def test_uid_requires_auth(self):
        with self.assertRaisesRegex(SqlError, "not_authenticated"):
            db().run("select app.uid();")
        # app is closed to API roles; the RPCs call it as their owner. Only the claim is needed here.
        self.assertEqual(db().run("set local \"request.jwt.claim.sub\" = '%s'; select app.uid();" % uuid(1)), [[uuid(1)]])

    def test_pair_for_is_canonical_and_idempotent(self):
        # pair_for's insert is not visible to subqueries of the same statement; call it first.
        rows = db().run(member(1) + member(2) + "select app.pair_for('%s','%s'); select app.pair_for('%s','%s') = app.pair_for('%s','%s'), (select count(*) from pair), (select a < b from pair);" % (uuid(1), uuid(2), uuid(1), uuid(2), uuid(2), uuid(1)))
        self.assertEqual(rows[-1], ["t", "1", "t"])
        with self.assertRaisesRegex(SqlError, "same_account"):
            db().run(member(1) + "select app.pair_for('%s','%s');" % (uuid(1), uuid(1)))

    def test_setup_complete_gates(self):
        ok = member(1) + "select app.setup_complete('%s');" % uuid(1)
        self.assertEqual(db().run(ok), [["t"]])
        for bad in [dict(birth='2010-01-01'), dict(visible=False), dict(photos=3), dict(status='deleted'), dict(gender='self', custom='x', photos=3)]:
            with self.subTest(bad=bad):
                self.assertEqual(db().run(member(1, **bad) + "select app.setup_complete('%s');" % uuid(1)), [["f"]])

    def test_mutual_preferences(self):
        def check(a, b):
            return db().run(member(1, **a) + member(2, **b) + "select app.mutual_preferences('%s','%s');" % (uuid(1), uuid(2)))[0][0]
        self.assertEqual(check(dict(gender='woman', interests='{men}'), dict(gender='man', interests='{women}')), 't')
        self.assertEqual(check(dict(gender='woman', interests='{men}'), dict(gender='man', interests='{men}')), 'f')
        self.assertEqual(check(dict(gender='self', custom='x', interests='{everyone}'), dict(gender='man', interests='{everyone}')), 't')
        self.assertEqual(check(dict(gender='self', custom='x', interests='{everyone}'), dict(gender='man', interests='{women,men,nonbinary}')), 'f')
        self.assertEqual(check(dict(birth='1920-01-01', interests='{everyone}', max_age=99), dict(interests='{everyone}', max_age=99)), 't')
        self.assertEqual(check(dict(birth='1920-01-01', interests='{everyone}'), dict(interests='{everyone}', max_age=98)), 'f')
        self.assertEqual(check(dict(interests='{everyone}', min_age=30), dict(interests='{everyone}')), 'f')

    def test_pair_open_and_eligible_pair(self):
        base = member(1) + member(2)
        self.assertEqual(db().run(base + "select app.eligible_pair('%s','%s');" % (uuid(1), uuid(2))), [["t"]])
        self.assertEqual(db().run(base + "insert into block(blocker, blocked) values ('%s','%s'); select app.eligible_pair('%s','%s');" % (uuid(2), uuid(1), uuid(1), uuid(2))), [["f"]])
        gone = base + "select app.pair_for('%s','%s'); update pair set disconnected_at = now(); select app.eligible_pair('%s','%s');" % (uuid(1), uuid(2), uuid(1), uuid(2))
        self.assertEqual(db().run(gone)[-1], ["f"])

    def test_effective_delay(self):
        self.assertEqual(db().run(member(1, delay=0) + member(2, delay=6) + "select app.effective_delay_hours('%s','%s');" % (uuid(1), uuid(2))), [["6"]])


if __name__ == "__main__":
    unittest.main()
