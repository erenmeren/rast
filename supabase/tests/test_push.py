import json
import unittest

from harness import SqlError, as_user, db, uuid
from test_discovery import call, like, released_group

TOKEN = "update device set push_token = 'tok-%d' where account_id = '%s';"
OUTBOX = "select coalesce(jsonb_agg(jsonb_build_array(recipient, kind, pair_id is not null) order by id), '[]')::text from push_outbox;"
MSG = "send_message('%s','%s','hi')"


def tokens(*ns):
    return "".join(TOKEN % (n, uuid(n)) for n in ns)


class PushTests(unittest.TestCase):
    def rows(self, sql):
        return json.loads(db().run(sql + OUTBOX)[-1][0])

    def test_like_notifies_target_only_once(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700) + like(1, 2, 701)
        self.assertEqual(self.rows(sql), [[uuid(2), "liked", True]])

    def test_match_notifies_both(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700) + like(2, 1, 701)
        kinds = sorted((r[0], r[1]) for r in self.rows(sql))
        self.assertEqual(kinds, sorted([(uuid(2), "liked"), (uuid(1), "matched"), (uuid(2), "matched")]))

    def test_message_notifies_other_member(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700) + like(2, 1, 701) + call(1, MSG % (uuid(2), uuid(702)))
        self.assertEqual(self.rows(sql)[-1], [uuid(2), "message", True])

    def test_preference_off_or_no_token_writes_nothing(self):
        off = "update preferences set notify_likes = false where account_id = '%s';" % uuid(2)
        self.assertEqual(self.rows(released_group(1, 2) + tokens(1, 2) + off + like(1, 2, 700)), [])
        self.assertEqual(self.rows(released_group(1, 2) + like(1, 2, 700)), [])

    def test_unavailable_like_writes_nothing(self):
        sql = released_group(1, 2) + tokens(1, 2) + call(2, "block_account('%s')" % uuid(1)) + like(1, 2, 700)
        self.assertEqual(self.rows(sql), [])

    def test_purge_removes_week_old_rows(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700)
        sql += "update push_outbox set created_at = now() - interval '8 days'; insert into push_outbox (recipient, kind) values ('%s', 'liked'); select app.purge_discovery();" % uuid(2)
        self.assertEqual(db().run(sql + "select count(*) from push_outbox;")[-1], ["1"])

    def test_privileges(self):
        sql = released_group(1, 2) + tokens(1, 2) + like(1, 2, 700)
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(sql + as_user(uuid(2), "select * from push_outbox;"))
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(as_user(uuid(2), "select app.notify('%s', 'liked', null);" % uuid(2)))
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(as_user(uuid(2), "select * from app.push_hook;"))


if __name__ == "__main__":
    unittest.main()
