import unittest

from harness import SqlError, as_user, db, member, uuid


class AccountTests(unittest.TestCase):
    def test_member_fixture_inserts_a_complete_member(self):
        rows = db().run(member(1) + "select (select count(*) from profile), (select count(*) from photo where state = 'ready'), (select delay_hours from preferences);")
        self.assertEqual(rows, [["1", "4", "2"]])

    def test_self_described_gender_needs_text(self):
        with self.assertRaises(SqlError):
            db().run(member(1, gender='self', custom=''))
        db().run(member(1, gender='self', custom='genderfluid'))

    def test_preference_constraints(self):
        for bad in [dict(min_age=30, max_age=20), dict(min_age=17), dict(max_age=100), dict(delay=3), dict(interval=20), dict(interests="{}")]:
            with self.subTest(bad=bad), self.assertRaises(SqlError):
                db().run(member(1, **bad))

    def test_everyone_cannot_combine_with_specific_interests(self):
        with self.assertRaises(SqlError):
            db().run(member(1, interests="{everyone,women}"))

    def test_photo_slot_unique_among_live_photos(self):
        sql = member(1) + "insert into photo(id, account_id, slot, storage_path, state) values (gen_random_uuid(), '%s', 0, 'x', 'uploading');" % uuid(1)
        with self.assertRaises(SqlError):
            db().run(sql)

    def test_rls_own_rows_only(self):
        sql = member(1) + member(2) + as_user(uuid(1), "select count(*) from profile; select count(*) from preferences; select count(*) from device;")
        self.assertEqual(db().run(sql), [["1"], ["1"], ["1"]])

    def test_client_cannot_undelete_or_delete_rows(self):
        base = member(1) + as_user(uuid(1), "select public.delete_account();")
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(base + as_user(uuid(1), "update account set status = 'active', deleted_at = null where id = '%s';" % uuid(1)))
        for table in ["account", "profile", "preferences", "photo", "device"]:
            with self.subTest(table=table), self.assertRaisesRegex(SqlError, "permission denied"):
                db().run(member(1) + as_user(uuid(1), "delete from %s;" % table))

    def test_anon_sees_nothing(self):
        with self.assertRaises(SqlError):
            db().run(member(1) + "set local role anon; select count(*) from profile;")


if __name__ == "__main__":
    unittest.main()
