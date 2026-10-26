import json
import unittest

from harness import SqlError, as_user, db, member, sample, uuid


def call(n, fn):
    return as_user(uuid(n), "select public.%s;" % fn)


def like(n, target, op):
    return call(n, "like_account('%s','%s')" % (uuid(target), uuid(op)))


def passes(n, target, op):
    return call(n, "pass_account('%s','%s')" % (uuid(target), uuid(op)))


SEED = "update discovery_session set seed = %d;"
SESSION = "(select id from discovery_session limit 1)"


def released_group(*ns, delay=0):
    """Members ns, all within 5 m one second ago, encounters released."""
    sql = "".join(member(n, delay=delay) for n in ns)
    sql += "".join(sample(n, 1, distance=i, observed="now() - interval '1 second'") for i, n in enumerate(ns))
    return sql + "select app.release_due_encounters();"


def cards(n, after="null", page_size=20):
    return call(n, "discovery_cards(%s, %s, %d)" % (SESSION, after, page_size))


class DiscoveryTests(unittest.TestCase):
    def base(self):
        return released_group(1, 2, 3, 4) + call(1, "start_discovery_session()")

    def last(self, sql):
        return json.loads(db().run(sql)[-1][0])

    def ids(self, result):
        return [c["account_id"] for c in result["cards"]]

    def test_order_depends_on_seed_not_time_and_is_stable(self):
        # pair ids are random per script, so every comparison happens inside one script
        sql = self.base() + "".join(SEED % seed + cards(1) + cards(1) for seed in range(1, 9))
        rows = db().run(sql)[-16:]
        orders = set()
        for i in range(0, 16, 2):
            first, second = (self.ids(json.loads(rows[i][0])), self.ids(json.loads(rows[i + 1][0])))
            self.assertEqual(sorted(first), [uuid(2), uuid(3), uuid(4)])
            self.assertEqual(first, second)
            orders.add(tuple(first))
        self.assertGreater(len(orders), 1)

    def test_card_shape(self):
        sql = self.base() + "update profile set show_gender = true where account_id = '%s';" % uuid(2)
        card = [c for c in self.last(sql + cards(1))["cards"] if c["account_id"] == uuid(2)][0]
        self.assertEqual(card, {"account_id": uuid(2), "age": 28, "gender": "woman", "custom_gender": "",
                                "photos": ["p2/0.jpg", "p2/1.jpg", "p2/2.jpg", "p2/3.jpg"]})
        hidden = [c for c in self.last(sql + cards(1))["cards"] if c["account_id"] == uuid(3)][0]
        self.assertIsNone(hidden["gender"])

    def test_pages_have_no_duplicates_and_no_gaps(self):
        sql = self.base() + SEED % 7 + as_user(uuid(1), "create temp table pg1 as select public.discovery_cards(%s, null, 2) as r;" % SESSION)
        sql += "select r from pg1;" + cards(1, after="(select r->>'next' from pg1)", page_size=2)
        rows = db().run(sql)
        page1, page2 = json.loads(rows[-2][0]), json.loads(rows[-1][0])
        self.assertEqual(len(page1["cards"]), 2)
        self.assertIsNotNone(page1["next"])
        self.assertEqual(len(page2["cards"]), 1)
        self.assertIsNone(page2["next"])
        self.assertEqual(sorted(self.ids(page1) + self.ids(page2)), [uuid(2), uuid(3), uuid(4)])

    def test_liked_and_passed_are_absent(self):
        sql = self.base() + like(1, 2, 700) + passes(1, 3, 701)
        self.assertEqual(self.ids(self.last(sql + cards(1))), [uuid(4)])

    def test_card_disappears_when_other_side_becomes_ineligible(self):
        for change in [call(1, "block_account('%s')" % uuid(2)),
                       call(2, "block_account('%s')" % uuid(1)),
                       "update profile set visible = false where account_id = '%s';" % uuid(2),
                       "update photo set state = 'removed' where account_id = '%s' and slot = 0;" % uuid(2),
                       "update account set status = 'deleted' where id = '%s';" % uuid(2)]:
            with self.subTest(change=change):
                self.assertNotIn(uuid(2), self.ids(self.last(self.base() + change + cards(1))))

    def test_foreign_or_expired_session(self):
        self.assertEqual(self.last(self.base() + cards(2))["outcome"], "session_expired")
        expired = self.base() + "update discovery_session set expires_at = now() - interval '1 second';"
        self.assertEqual(self.last(expired + cards(1))["outcome"], "session_expired")

    def test_new_session_replaces_old(self):
        rows = db().run(self.base() + call(1, "start_discovery_session()") + "select count(*) from discovery_session;")
        self.assertEqual(rows[-1], ["1"])

    def test_page_size_is_clamped(self):
        for size in (0, -5, 500):
            with self.subTest(size=size):
                self.assertEqual(self.last(self.base() + cards(1, page_size=size))["outcome"], "ok")

    def test_bad_cursor(self):
        self.assertEqual(self.last(self.base() + cards(1, after="'abc'"))["outcome"], "bad_cursor")

    def test_late_candidate_joins_only_after_its_slot(self):
        sql = self.base() + SEED % 3 + as_user(uuid(1), "create temp table pg1 as select public.discovery_cards(%s, null, 2) as r;" % SESSION)
        sql += member(5, delay=0) + sample(5, 1, distance=4, observed="now() - interval '1 second'") + "select app.release_due_encounters();"
        sql += "select r->>'next' from pg1;"
        sql += "select app.order_key(3, app.pair_for('%s','%s'));" % (uuid(1), uuid(5))
        sql += cards(1, after="(select r->>'next' from pg1)", page_size=20)
        sql += call(1, "start_discovery_session()") + cards(1)
        rows = db().run(sql)
        cursor, key = int(rows[-5][0]), int(rows[-4][0])
        page2, fresh = json.loads(rows[-3][0]), json.loads(rows[-1][0])
        self.assertEqual(uuid(5) in self.ids(page2), key > cursor)
        self.assertIn(uuid(5), self.ids(fresh))

    def test_pass_hides_and_rewind_restores(self):
        sql = self.base() + passes(1, 2, 701)
        self.assertEqual(self.last(sql)["outcome"], "passed")
        self.assertEqual(self.last(sql + passes(1, 2, 702))["outcome"], "passed")
        self.assertNotIn(uuid(2), self.ids(self.last(sql + cards(1))))
        self.assertEqual(self.last(sql + call(1, "rewind_pass()")), {"outcome": "restored", "account_id": uuid(2)})
        self.assertIn(uuid(2), self.ids(self.last(sql + call(1, "rewind_pass()") + cards(1))))
        self.assertEqual(db().run(sql + "select count(*) from pair_event;")[-1], ["0"])

    def test_rewind_keeps_pass_when_pair_is_closed(self):
        sql = self.base() + passes(1, 2, 701) + call(1, "block_account('%s')" % uuid(2))
        self.assertEqual(self.last(sql + call(1, "rewind_pass()"))["outcome"], "unavailable")
        self.assertEqual(db().run(sql + "select count(*) from pair_pass;")[-1], ["1"])
        self.assertEqual(self.last(self.base() + call(1, "rewind_pass()"))["outcome"], "unavailable")

    def test_pass_on_pending_pair_is_unavailable(self):
        self.assertEqual(self.last(released_group(1, 2, delay=2) + passes(1, 2, 701))["outcome"], "unavailable")

    def test_rewind_lookup_has_an_index(self):
        rows = db().run("select count(*) from pg_indexes where tablename = 'pair_pass' and indexdef like '%(from_account, created_at DESC)';")
        self.assertEqual(rows[-1], ["1"])

    def test_privileges(self):
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run("set local role anon; select public.start_discovery_session();")
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(as_user(uuid(1), "select app.candidate('%s', gen_random_uuid());" % uuid(1)))
        rows = db().run(self.base() + as_user(uuid(1), "select count(*) from discovery_session;")
                        + as_user(uuid(2), "select count(*) from discovery_session;"))
        self.assertEqual(rows[-2:], [["1"], ["0"]])


if __name__ == "__main__":
    unittest.main()
