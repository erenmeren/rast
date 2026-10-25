import json
import unittest

from harness import SqlError, as_user, db, member, sample, uuid


def call(n, fn):
    return as_user(uuid(n), "select public.%s;" % fn)


def like(n, target, op):
    return call(n, "like_account('%s','%s')" % (uuid(target), uuid(op)))


class PairOpsTests(unittest.TestCase):
    def released(self):
        return (member(1, delay=0) + member(2, delay=0) + sample(1, 1, observed="now() - interval '1 second'")
                + sample(2, 1, distance=5, observed="now() - interval '1 second'") + "select app.release_due_encounters();")

    def matched(self):
        return self.released() + like(1, 2, 700) + like(2, 1, 701)

    def last(self, sql):
        return json.loads(db().run(sql)[-1][0])

    def test_like_then_mutual_like_matches(self):
        sql = self.released() + like(1, 2, 700)
        self.assertEqual(self.last(sql)["outcome"], "liked")
        sql += like(2, 1, 701)
        self.assertEqual(self.last(sql)["outcome"], "matched")
        self.assertEqual(db().run(sql + "select matched_at is not null, revision from pair;")[-1], ["t", "2"])

    def test_like_without_released_encounter_is_unavailable(self):
        self.assertEqual(self.last(member(1) + member(2) + like(1, 2, 700))["outcome"], "unavailable")

    def test_like_self_is_unavailable(self):
        self.assertEqual(self.last(member(1) + like(1, 1, 700))["outcome"], "unavailable")

    def test_disconnect_is_idempotent_and_closes_everything(self):
        sql = self.matched() + call(2, "disconnect_pair('%s','%s')" % (uuid(1), uuid(702)))
        self.assertEqual(self.last(sql)["outcome"], "disconnected")
        sql += call(2, "disconnect_pair('%s','%s')" % (uuid(1), uuid(702)))
        self.assertEqual(self.last(sql)["outcome"], "disconnected")
        rows = db().run(sql + "select revision, disconnected_at is not null from pair; select state from encounter; select count(*) from pair_event where kind = 'disconnected';")
        self.assertEqual(rows[-3:], [["3", "t"], ["void"], ["1"]])
        for fn in ["like_account('%s','%s')" % (uuid(2), uuid(703)), "send_message('%s','%s','hi')" % (uuid(2), uuid(704))]:
            with self.subTest(fn=fn):
                self.assertEqual(self.last(sql + call(1, fn))["outcome"], "unavailable")

    def test_disconnect_without_match_works(self):
        self.assertEqual(self.last(member(1) + member(2) + call(1, "disconnect_pair('%s','%s')" % (uuid(2), uuid(702))))["outcome"], "disconnected")

    def test_block_on_match_disconnects_unblock_keeps_tombstone(self):
        sql = self.matched() + call(1, "block_account('%s')" % uuid(2)) + call(1, "unblock_account('%s')" % uuid(2))
        rows = db().run(sql + "select count(*) from block; select disconnected_at is not null from pair;")
        self.assertEqual(rows[-2:], [["0"], ["t"]])

    def test_block_unmatched_then_unblock_restores_eligibility(self):
        sql = member(1) + member(2) + call(1, "block_account('%s')" % uuid(2))
        self.assertEqual(db().run(sql + "select app.eligible_pair('%s','%s');" % (uuid(1), uuid(2)))[-1], ["f"])
        sql += call(1, "unblock_account('%s')" % uuid(2))
        self.assertEqual(db().run(sql + "select app.eligible_pair('%s','%s');" % (uuid(1), uuid(2)))[-1], ["t"])

    def test_report_with_block_on_match(self):
        sql = self.matched() + call(1, "submit_report('%s','harassment','%s', true)" % (uuid(2), uuid(705)))
        self.assertEqual(self.last(sql)["outcome"], "received")
        rows = db().run(sql + "select count(*) from report; select count(*) from block; select disconnected_at is not null from pair;")
        self.assertEqual(rows[-3:], [["1"], ["1"], ["t"]])
        sql += call(1, "submit_report('%s','harassment','%s', true)" % (uuid(2), uuid(705)))
        self.assertEqual(db().run(sql + "select count(*) from report;")[-1], ["1"])

    def test_report_without_block_keeps_connection(self):
        sql = self.matched() + call(1, "submit_report('%s','spam','%s', false)" % (uuid(2), uuid(705)))
        self.assertEqual(db().run(sql + "select disconnected_at is null from pair;")[-1], ["t"])

    def test_messages_dense_seq_and_idempotent(self):
        sql = (self.matched() + call(1, "send_message('%s','%s','hello')" % (uuid(2), uuid(710)))
               + call(2, "send_message('%s','%s','hi')" % (uuid(1), uuid(711)))
               + call(1, "send_message('%s','%s','hello')" % (uuid(2), uuid(710))))
        rows = db().run(sql + "select count(*), max(seq) from message;")
        self.assertEqual(rows[-1], ["2", "2"])
        self.assertEqual(self.last(sql)["seq"], 1)
        self.assertEqual(self.last(self.released() + call(1, "send_message('%s','%s','x')" % (uuid(2), uuid(712))))["outcome"], "unavailable")
        with self.assertRaisesRegex(SqlError, "message_body_check"):
            db().run(sql + call(1, "send_message('%s','%s','')" % (uuid(2), uuid(713))))

    def test_message_self_is_unavailable(self):
        self.assertEqual(self.last(member(1) + call(1, "send_message('%s','%s','hi')" % (uuid(1), uuid(714))))["outcome"], "unavailable")

    def test_delete_account(self):
        sql = self.released() + call(1, "delete_account()")
        rows = db().run(sql + "select status from account where id = '%s'; select visible from profile where account_id = '%s'; select count(*) from pair; select state from encounter;" % (uuid(1), uuid(1)))
        self.assertEqual(rows[-4:], [["deleted"], ["f"], ["1"], ["void"]])

    def test_messages_unavailable_after_delete(self):
        sql = self.matched() + call(2, "delete_account()")
        self.assertEqual(self.last(sql + call(1, "send_message('%s','%s','hi')" % (uuid(2), uuid(720))))["outcome"], "unavailable")
        self.assertEqual(self.last(sql + call(2, "send_message('%s','%s','hi')" % (uuid(1), uuid(721))))["outcome"], "unavailable")
        self.assertEqual(db().run(sql + "select disconnected_at is not null from pair; select kind from pair_event order by id desc limit 1;")[-2:], [["t"], ["disconnected"]])

    def test_disconnect_waits_for_in_flight_like(self):
        db().run(self.released(), commit=True)
        a = as_user(uuid(1), "select public.like_account('%s','%s'); select pg_sleep(2);" % (uuid(2), uuid(700)))
        b = as_user(uuid(2), "select public.disconnect_pair('%s','%s');" % (uuid(1), uuid(702)))
        try:
            _, out_b = db().run_concurrent(a, b)
            self.assertEqual(json.loads(out_b[-1][0])["outcome"], "disconnected")
            self.assertEqual(db().run("select disconnected_at is not null, matched_at is null, revision from pair;"), [["t", "t", "2"]])
            self.assertEqual(db().run("select kind from pair_event order by id;"), [["disconnected"]])
            self.assertEqual(db().run("select count(*) from pair_like;"), [["1"]])
        finally:
            db().run("truncate auth.users cascade; truncate pair cascade;", commit=True)

    def test_disconnect_waits_for_in_flight_matching_like(self):
        db().run(self.released() + like(2, 1, 701), commit=True)
        a = as_user(uuid(1), "select public.like_account('%s','%s'); select pg_sleep(2);" % (uuid(2), uuid(700)))
        b = as_user(uuid(2), "select public.disconnect_pair('%s','%s');" % (uuid(1), uuid(702)))
        try:
            out_a, out_b = db().run_concurrent(a, b)
            self.assertEqual(json.loads(out_a[0][0])["outcome"], "matched")
            self.assertEqual(json.loads(out_b[-1][0])["outcome"], "disconnected")
            self.assertEqual(db().run("select kind from pair_event order by id;"), [["matched"], ["disconnected"]])
        finally:
            db().run("truncate auth.users cascade; truncate pair cascade;", commit=True)


if __name__ == "__main__":
    unittest.main()
