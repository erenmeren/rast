import json
import unittest

from harness import SqlError, as_user, db, member, uuid
from test_discovery import SEED, SESSION, call, cards, like, passes, released_group


class FollowupTests(unittest.TestCase):
    def last(self, sql):
        return json.loads(db().run(sql)[-1][0])

    def test_disconnected_accounts_lists_removed_connections_with_age(self):
        sql = released_group(1, 2, 3) + like(1, 2, 700) + like(2, 1, 701) + call(1, "disconnect_pair('%s','%s')" % (uuid(2), uuid(702)))
        self.assertEqual(self.last(sql + call(1, "disconnected_accounts()"))["disconnected"], [{"account_id": uuid(2), "age": 28}])
        self.assertEqual(self.last(released_group(1, 2) + call(1, "disconnected_accounts()"))["disconnected"], [])

    def test_session_seed_is_not_readable_and_sessions_cannot_pile_up(self):
        sql = released_group(1, 2) + call(1, "start_discovery_session()")
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(sql + as_user(uuid(1), "select seed from discovery_session;"))
        self.assertEqual(db().run(sql + as_user(uuid(1), "select count(*) from discovery_session;"))[-1], ["1"])
        with self.assertRaisesRegex(SqlError, "discovery_session_account_key"):
            db().run(sql + "insert into discovery_session(account_id, seed) values ('%s', 1);" % uuid(1))

    def test_repeated_pass_counts_as_the_most_recent(self):
        sql = released_group(1, 2, 3) + passes(1, 2, 701) + passes(1, 3, 702) + passes(1, 2, 703)
        self.assertEqual(self.last(sql + call(1, "rewind_pass()"))["account_id"], uuid(2))

    def test_privileges(self):
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run("set local role anon; select public.disconnected_accounts();")


if __name__ == "__main__":
    unittest.main()
