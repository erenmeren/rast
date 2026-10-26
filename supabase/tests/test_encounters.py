import json
import unittest

from harness import SqlError, as_user, db, member, sample, uuid


class EncounterTests(unittest.TestCase):
    def two(self, **kw):
        return member(1, **kw.get('a', {})) + member(2, **kw.get('b', {}))

    def count(self, sql):
        return db().run(sql + "select count(*) from encounter;")[-1][0]

    def test_rule_01_20_metres_passes(self):
        self.assertEqual(self.count(self.two() + sample(1, 1) + sample(2, 1, distance=20.0)), "1")

    def test_rule_02_03_beyond_20_fails(self):
        for d in [20.001, 35, 40]:
            with self.subTest(d=d):
                self.assertEqual(self.count(self.two() + sample(1, 1) + sample(2, 1, distance=d)), "0")

    def test_encounter_fields(self):
        t0 = "date_trunc('hour', now()) - interval '2 hours'"
        rows = db().run(self.two(a=dict(delay=1), b=dict(delay=4)) + sample(1, 1, observed=t0) + sample(2, 1, distance=5, observed=t0 + " + interval '30 seconds'")
                        + "select state, rule_version, encountered_at = %s + interval '30 seconds', release_at = %s + interval '4 hours 30 seconds', pair_id = app.pair_for('%s','%s') from encounter;" % (t0, t0, uuid(1), uuid(2)))
        self.assertEqual(rows[-1], ["pending", "1", "t", "t", "t"])

    def test_rule_04_ineligible_pairs(self):
        cases = [dict(a=dict(birth='2010-01-01')), dict(a=dict(visible=False)), dict(b=dict(photos=3)),
                 dict(a=dict(interests='{women}'), b=dict(gender='man')), dict(a=dict(max_age=25), b=dict(birth='1990-01-01'))]
        for c in cases:
            with self.subTest(c=c):
                self.assertEqual(self.count(self.two(**c) + sample(1, 1) + sample(2, 1, distance=5)), "0")
        blocked = self.two() + "insert into block(blocker, blocked) values ('%s','%s');" % (uuid(1), uuid(2))
        self.assertEqual(self.count(blocked + sample(1, 1) + sample(2, 1, distance=5)), "0")
        gone = self.two() + "select app.pair_for('%s','%s'); update pair set disconnected_at = now();" % (uuid(1), uuid(2))
        self.assertEqual(self.count(gone + sample(1, 1) + sample(2, 1, distance=5)), "0")

    def test_rule_05_stale_skewed_or_inaccurate(self):
        self.assertEqual(self.count(self.two() + sample(1, 1, observed="now() - interval '61 seconds'") + sample(2, 1, distance=5)), "0")
        self.assertEqual(self.count(self.two() + sample(1, 1, observed="now() - interval '59 seconds'") + sample(2, 1, distance=5)), "1")
        self.assertEqual(self.count(self.two() + sample(1, 1, accuracy=51) + sample(2, 1, distance=5)), "0")

    def test_rejections_are_reported(self):
        def result(sql):
            return json.loads(db().run(member(1) + member(2) + sql)[-1][0])
        self.assertEqual(result(sample(1, 1, observed="now() - interval '25 hours'"))["rejected"][0]["reason"], "too_old")
        self.assertEqual(result(sample(1, 1, observed="now() + interval '2 minutes'"))["rejected"][0]["reason"], "future")
        self.assertEqual(result(sample(1, 1, accuracy=51))["rejected"][0]["reason"], "inaccurate")
        self.assertEqual(result(sample(1, 1, device=uuid(102)))["rejected"][0]["reason"], "device")
        self.assertEqual(result(sample(1, 1, lat=91))["rejected"][0]["reason"], "malformed")
        ok = result(sample(1, 1, sample_id=uuid(900)))
        self.assertEqual((ok["accepted"], ok["rejected"]), ([uuid(900)], []))

    def test_duplicate_seq_is_accepted_once(self):
        rows = db().run(member(1) + sample(1, 1, sample_id=uuid(900)) + sample(1, 1, sample_id=uuid(901)) + "select count(*) from location_sample;")
        self.assertEqual(rows[-1], ["1"])
        self.assertEqual(json.loads(rows[1][0])["accepted"], [uuid(901)])

    def test_empty_and_invalid_payloads(self):
        self.assertEqual(json.loads(db().run(member(1) + as_user(uuid(1), "select public.submit_location_samples('[]');"))[0][0]), {"accepted": [], "rejected": []})
        with self.assertRaisesRegex(SqlError, "array"):
            db().run(member(1) + as_user(uuid(1), "select public.submit_location_samples('{\"a\":1}');"))

    def test_response_names_no_one_else(self):
        out = db().run(self.two() + sample(1, 1) + sample(2, 1, distance=5))[-1][0]
        self.assertNotIn(uuid(1), out)

    def test_one_live_encounter_per_pair(self):
        sql = self.two() + sample(1, 1) + sample(2, 1, distance=5) + sample(1, 2, distance=1) + sample(2, 2, distance=2)
        self.assertEqual(self.count(sql), "1")

    def test_release_due_flips_at_boundary(self):
        base = self.two(a=dict(delay=0), b=dict(delay=0)) + sample(1, 1, observed="now() - interval '1 second'") + sample(2, 1, distance=5, observed="now() - interval '1 second'")
        self.assertEqual(db().run(base + "select app.release_due_encounters(); select state from encounter;")[-2:], [["1"], ["released"]])
        later = self.two(a=dict(delay=1), b=dict(delay=0)) + sample(1, 1) + sample(2, 1, distance=5)
        self.assertEqual(db().run(later + "select app.release_due_encounters(); select state from encounter;")[-2:], [["0"], ["pending"]])

    def test_concurrent_intake_still_pairs(self):
        db().run(self.two(), commit=True)
        try:
            db().run_concurrent(sample(1, 1) + "select pg_sleep(1.5);", sample(2, 1, distance=5))
            self.assertEqual(db().run("select count(*) from encounter;"), [["1"]])
        finally:
            db().run("truncate auth.users cascade; truncate pair cascade;", commit=True)

    def test_clients_cannot_read_samples(self):
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(member(1) + sample(1, 1) + as_user(uuid(1), "select count(*) from location_sample;"))


if __name__ == "__main__":
    unittest.main()
