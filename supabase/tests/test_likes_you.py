import json
import unittest

from harness import SqlError, as_user, db, member, sample, uuid
from test_discovery import call, like, passes, released_group


def premium(n, valid="null"):
    return "insert into entitlement(account_id, product, status, valid_until) values ('%s', 'premium', 'active', %s);" % (uuid(n), valid)


class LikesYouTests(unittest.TestCase):
    def base(self):
        return released_group(1, 2, 3, 4) + like(2, 1, 700) + like(3, 1, 701)

    def last(self, sql):
        return json.loads(db().run(sql)[-1][0])

    def test_free_member_gets_count_and_previews_only(self):
        r = self.last(self.base() + call(1, "likes_you()"))
        self.assertEqual((r["outcome"], r["premium"], r["count"]), ("ok", False, 2))
        self.assertEqual(sorted(p["age"] for p in r["previews"]), [28, 28])
        self.assertNotIn("cards", r)
        self.assertEqual(set(r["previews"][0]), {"token", "age"})

    def test_premium_member_gets_cards(self):
        r = self.last(self.base() + premium(1) + call(1, "likes_you()"))
        self.assertEqual((r["premium"], r["count"]), (True, 2))
        self.assertEqual(sorted(c["account_id"] for c in r["cards"]), [uuid(2), uuid(3)])
        self.assertNotIn("previews", r)

    def test_expired_entitlement_is_free(self):
        r = self.last(self.base() + premium(1, "now() - interval '1 day'") + call(1, "likes_you()"))
        self.assertFalse(r["premium"])

    def test_passed_liker_and_pending_liker_are_excluded(self):
        sql = self.base() + passes(1, 2, 702)
        self.assertEqual(self.last(sql + call(1, "likes_you()"))["count"], 1)
        pending = (released_group(1, 2, delay=2)
                   + "insert into pair_like(pair_id, from_account) values (app.pair_for('%s','%s'), '%s');" % (uuid(1), uuid(2), uuid(2)))
        self.assertEqual(self.last(pending + call(1, "likes_you()"))["count"], 0)

    def test_incomplete_setup_sees_no_likes(self):
        sql = self.base() + "update profile set visible = false where account_id = '%s';" % uuid(1)
        self.assertEqual(self.last(sql + call(1, "likes_you()"))["count"], 0)

    def test_tokens_are_reused_and_closed_to_clients(self):
        sql = self.base() + call(1, "likes_you()")
        rows = db().run(sql + call(1, "likes_you()"))
        first = {p["token"] for p in json.loads(rows[-2][0])["previews"]}
        second = {p["token"] for p in json.loads(rows[-1][0])["previews"]}
        self.assertEqual(len(first), 2)
        self.assertEqual(first, second)
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(sql + as_user(uuid(1), "select * from like_preview;"))

    def test_can_view_photos(self):
        base = self.base()
        matched = base + like(1, 2, 703)
        checks = [
            (base, 1, 1, "t"), (base, 1, 2, "t"), (base, 4, 1, "t"),
            (matched, 1, 2, "t"), (matched, 2, 1, "t"),
            (base, 1, 3, "t"), (base, 2, 3, "t"),
            (base, 1, 5, "f"),
            (base + call(1, "block_account('%s')" % uuid(2)), 1, 2, "f"),
            (released_group(1, 2, delay=2), 1, 2, "f"),
            (matched + call(1, "disconnect_pair('%s','%s')" % (uuid(2), uuid(704))), 1, 2, "f"),
        ]
        for sql, v, o, want in checks:
            with self.subTest(viewer=v, owner=o, want=want):
                self.assertEqual(db().run(sql + "select app.can_view_photos('%s','%s');" % (uuid(v), uuid(o)))[-1], [want])

    def test_purge_discovery(self):
        sql = (self.base() + call(1, "likes_you()") + call(1, "start_discovery_session()")
               + "update like_preview set expires_at = now() - interval '1 second'; update discovery_session set expires_at = now() - interval '1 second';")
        rows = db().run(sql + "select app.purge_discovery(); select count(*) from like_preview; select count(*) from discovery_session;")
        self.assertEqual(rows[-3:], [["3"], ["0"], ["0"]])

    def test_privileges(self):
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run("set local role anon; select public.likes_you();")
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(as_user(uuid(1), "select app.is_premium('%s');" % uuid(1)))


if __name__ == "__main__":
    unittest.main()
