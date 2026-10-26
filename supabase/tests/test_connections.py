import json
import unittest

from harness import SqlError, as_user, db, member, uuid
from test_discovery import call, like, released_group


class ConnectionsTests(unittest.TestCase):
    def matched(self):
        return released_group(1, 2, 3) + like(1, 2, 700) + like(2, 1, 701)

    def last(self, sql):
        return json.loads(db().run(sql)[-1][0])

    def test_connections_lists_open_matches_with_the_partner_card(self):
        r = self.last(self.matched() + call(1, "connections()"))
        self.assertEqual(r["outcome"], "ok")
        self.assertEqual(len(r["connections"]), 1)
        c = r["connections"][0]
        self.assertEqual(c["card"]["account_id"], uuid(2))
        self.assertEqual(c["revision"], 2)
        self.assertEqual(set(c), {"pair_id", "revision", "card"})
        gone = self.matched() + call(1, "disconnect_pair('%s','%s')" % (uuid(2), uuid(702)))
        self.assertEqual(self.last(gone + call(1, "connections()"))["connections"], [])
        blocked = self.matched() + call(2, "block_account('%s')" % uuid(1))
        self.assertEqual(self.last(blocked + call(1, "connections()"))["connections"], [])

    def test_person_card(self):
        base = released_group(1, 2, 3)
        self.assertEqual(self.last(base + call(1, "person_card('%s')" % uuid(2)))["card"]["account_id"], uuid(2))
        self.assertEqual(self.last(self.matched() + call(1, "person_card('%s')" % uuid(2)))["outcome"], "ok")
        self.assertEqual(self.last(base + member(9) + call(1, "person_card('%s')" % uuid(9)))["outcome"], "unavailable")
        self.assertEqual(self.last(base + call(1, "block_account('%s')" % uuid(2)) + call(1, "person_card('%s')" % uuid(2)))["outcome"], "unavailable")
        self.assertEqual(self.last(base + call(1, "person_card('%s')" % uuid(1)))["outcome"], "unavailable")

    def test_blocked_accounts(self):
        sql = released_group(1, 2, 3) + call(1, "block_account('%s')" % uuid(2))
        r = self.last(sql + call(1, "blocked_accounts()"))
        self.assertEqual(r["blocked"], [{"account_id": uuid(2), "age": 28}])
        self.assertEqual(self.last(sql + call(1, "unblock_account('%s')" % uuid(2)) + call(1, "blocked_accounts()"))["blocked"], [])

    def test_privileges(self):
        for fn in ["connections()", "person_card(gen_random_uuid())", "blocked_accounts()"]:
            with self.subTest(fn=fn), self.assertRaisesRegex(SqlError, "permission denied"):
                db().run("set local role anon; select public.%s;" % fn)


if __name__ == "__main__":
    unittest.main()
